class AppointmentNotification::Worker
  include Rails.application.routes.url_helpers
  include Sidekiq::Worker

  sidekiq_options queue: :high

  DEFAULT_LOCALE = :en

  def metrics
    @metrics ||= Metrics.with_object(self)
  end

  def perform(appointment_id, communication_type, locale = nil)
    metrics.increment("attempts")
    unless Flipper.enabled?(:appointment_reminders)
      metrics.increment("skipped.feature_disabled")
      return
    end

    appointment = Appointment.find_by(id: appointment_id)
    unless appointment
      metrics.increment("skipped.missed_appointment")
      logger.warn "Appointment #{appointment_id} not found, skipping notification"
      return
    end

    if appointment.previously_communicated_via?(communication_type)
      metrics.increment("skipped.previously_communicated")
      return
    end

    patient_phone_number = appointment.patient.latest_mobile_number
    message = appointment_message(appointment, communication_type, locale)

    begin
      notification_service = NotificationService.new

      response = if communication_type == "missed_visit_whatsapp_reminder"
        notification_service.send_whatsapp(patient_phone_number, message, callback_url).tap do |resp|
          metrics.increment("sent.whatsapp")
        end
      else
        notification_service.send_sms(patient_phone_number, message, callback_url).tap do |response|
          metrics.increment("sent.sms")
        end
      end

      Communication.create_with_twilio_details!(
        appointment: appointment,
        twilio_sid: response.sid,
        twilio_msg_status: response.status,
        communication_type: communication_type
      )
    rescue Twilio::REST::TwilioError => e
      metrics.increment(:error)
      report_error(e)
    end
  end

  private

  def appointment_message(appointment, communication_type, locale)
    I18n.t(
      "sms.appointment_reminders.#{communication_type}",
      facility_name: appointment.facility.name,
      locale: appointment_locale(appointment, locale)
    )
  end

  def appointment_locale(appointment, locale)
    locale || appointment.patient.address&.locale || DEFAULT_LOCALE
  end

  def report_error(e)
    Sentry.capture_message("Error while processing appointment notifications",
      extra: {
        exception: e.to_s
      },
      tags: {
        type: "appointment-notification-job"
      })
  end

  def callback_url
    api_v3_twilio_sms_delivery_url(
      host: ENV.fetch("SIMPLE_SERVER_HOST"),
      protocol: ENV.fetch("SIMPLE_SERVER_HOST_PROTOCOL")
    )
  end
end
