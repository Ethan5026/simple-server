class Notification < ApplicationRecord
  belongs_to :subject, optional: true, polymorphic: true
  belongs_to :patient
  belongs_to :experiment, class_name: "Experimentation::Experiment", optional: true
  belongs_to :reminder_template, class_name: "Experimentation::ReminderTemplate", optional: true
  has_many :communications

  # A common logger for all notification related things - adding the top level module tag here will
  # make things easy to scan for in Datadog.
  def self.logger(extra_fields = {})
    fields = {module: :notifications}.merge(extra_fields)
    Rails.logger.child(fields)
  end

  validates :status, presence: true
  validates :remind_on, presence: true
  validates :message, presence: true
  validates :purpose, presence: true
  validates :subject, presence: true, if: proc { |n| n.missed_visit_reminder? }, on: :create

  enum status: {
    pending: "pending",
    scheduled: "scheduled",
    sent: "sent",
    cancelled: "cancelled"
  }, _prefix: true

  enum purpose: {
    covid_medication_reminder: "covid_medication_reminder",
    experimental_appointment_reminder: "experimental_appointment_reminder",
    missed_visit_reminder: "missed_visit_reminder",
    test_message: "test_message"
  }

  scope :due_today, -> { where(remind_on: Date.current, status: [:pending]) }

  def self.cancel
    where(status: %w[pending scheduled]).update_all(status: :cancelled)
  end

  def message_data
    case purpose
      when "covid_medication_reminder"
        covid_medication_reminder_message_data
      when "experimental_appointment_reminder"
        experimental_appointment_reminder_message_data
      when "missed_visit_reminder"
        missed_visit_reminder_message_data
      when "test_message"
        test_message_reminder_message_data
      else
        raise ArgumentError, "No localized_message defined for notification of type #{purpose}"
    end
  end

  def localized_message
    I18n.t(message_data[:message], **message_data[:vars], locale: message_data[:locale])
  end

  def successful_deliveries
    # TODO: this will need to become channel aware after BSNL
    communications.with_delivery_detail.select("delivery_detail.result, communications.*").where(
      delivery_detail: {result: [:read, :delivered, :sent]}
    )
  end

  def queued_deliveries
    # TODO: this will need to become channel aware after BSNL
    communications.with_delivery_detail.select("delivery_detail.result, communications.*").where(
      delivery_detail: {result: [:queued]}
    )
  end

  def delivery_result
    if status_cancelled?
      :failed
    elsif successful_deliveries.exists?
      :success
    elsif queued_deliveries.exists? || !communications.exists?
      :queued
    else
      :failed
    end
  end

  private

  def covid_medication_reminder_message_data
    return unless patient

    { message: message,
      vars: { facility_name: patient.assigned_facility,
              patient_name: patient.full_name },
      locale: patient.locale }
  end

  def experimental_appointment_reminder_message_data
    return unless patient

    facility = subject&.facility || patient.assigned_facility
    { message: message,
      vars: { facility_name: facility.name,
              patient_name: patient.full_name,
              appointment_date: subject&.scheduled_date&.strftime("%d-%m-%Y") },
      locale: facility.locale }
  end

  def missed_visit_reminder_message_data
    return unless patient

    { message: message,
      vars: { facility_name: subject.facility.name,
              patient_name: patient.full_name,
              appointment_date: subject.scheduled_date.strftime("%d-%m-%Y") },
      locale: subject.facility.locale }
  end

  def test_message_reminder_message_data
    return unless notification.patient

    { message: "Test message sent by Simple.org to #{notification.patient.full_name}",
      vars: {},
      locale: "en-IN" }
  end
end
