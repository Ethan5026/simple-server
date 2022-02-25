class AppointmentNotification::Worker
  include Sidekiq::Worker

  sidekiq_options queue: :default

  def perform(notification_id)
    send_message(ExperimentalAppointmentReminder.includes(:patient).find(notification_id))
  end

  private

  def send_message(notification)
    response = NotificationDispatchService.new(notification, appointment_reminder_service).send_message
    record_communication(notification, response) if response
  end

  def appointment_reminder_service
    CountryConfig.current[:appointment_reminder_service]
  end

  def record_communication(notification, response)
    ActiveRecord::Base.transaction do
      # TODO: fix communication_type
      create_communication(notification, "sms", response)
      notification.status_sent!
    end
  end

  def create_communication(notification, communication_type, response)
    Communication.create_with_twilio_details!(
      appointment: notification.subject,
      notification: notification,
      twilio_sid: response.sid,
      twilio_msg_status: response.status,
      communication_type: communication_type
    )
  end
end
