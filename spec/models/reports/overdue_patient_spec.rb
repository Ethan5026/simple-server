require "rails_helper"

RSpec.describe Reports::OverduePatient, {type: :model, reporting_spec: true} do
  around do |example|
    freeze_time_for_reporting_specs(example)
  end

  describe "Associations" do
    it { should belong_to(:patient) }
  end

  describe "Model" do
    it "should not include dead patients" do
      create(:patient)
      dead_patient = create(:patient, status: "dead")
      Reports::PatientState.refresh
      described_class.refresh

      with_reporting_time_zone do
        expect(described_class.count).not_to eq 0
        expect(described_class.where(patient_id: dead_patient.id)).to be_empty
      end
    end
  end

  context "indicators" do
    describe "next_called_at" do
      it "should only select the first call that took place during the month" do
        patient = create(:patient)
        month_date = june_2021[:now]
        call_result_1 = create(:call_result, patient: patient, device_created_at: month_date + 2.days)
        _call_result_2 = create(:call_result, patient: patient, device_created_at: month_date + 3.days)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).next_called_at).to eq(call_result_1.device_created_at)
        end
      end

      it "should not select the call that took place after the month" do
        patient = create(:patient)
        month_date = june_2021[:now]
        _call_result_1 = create(:call_result, patient: patient, device_created_at: month_date + 1.month)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).next_called_at).to be_nil
        end
      end

      it "should not select the call that took place before the month" do
        patient = create(:patient)
        month_date = june_2021[:now]
        _call_result_1 = create(:call_result, patient: patient, device_created_at: month_date - 1.hour)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).next_called_at).to be_nil
        end
      end
    end

    describe "previous_called_at" do
      it "should only select the latest call in the previous month" do
        patient = create(:patient)
        month_date = june_2021[:now]
        appointment = create(:appointment, patient: patient, device_created_at: june_2021[:two_months_ago], scheduled_date: month_date - 15.days)
        _call_result_1 = create(:call_result, patient: patient, appointment: appointment, device_created_at: month_date - 15.days + 1.day)
        call_result_2 = create(:call_result, patient: patient, appointment: appointment, device_created_at: month_date - 15.days + 2.days)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).previous_called_at).to eq(call_result_2.device_created_at)
        end
      end

      it "should only select the call that was made after the scheduled date of latest appointment" do
        patient = create(:patient)
        month_date = june_2021[:now]
        appointment = create(:appointment, patient: patient, device_created_at: june_2021[:two_months_ago], scheduled_date: month_date - 15.days)
        _call_result_1 = create(:call_result, patient: patient, appointment: appointment, device_created_at: month_date - 15.days - 1.day)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).previous_called_at).to be_nil
        end
      end
    end

    describe "previous_appointment_id" do
      it "should only select the latest appointment in the previous month" do
        patient = create(:patient)
        month_date = june_2021[:now]
        _appointment_1 = create(:appointment, patient: patient, device_created_at: june_2021[:two_months_ago])
        appointment_2 = create(:appointment, patient: patient, device_created_at: june_2021[:two_months_ago] + 15.days)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).previous_appointment_id).to eq(appointment_2.id)
        end
      end

      it "should pick cancelled appointments also" do
        patient = create(:patient)
        month_date = june_2021[:now]
        _appointment_1 = create(:appointment, patient: patient, device_created_at: month_date - 30.days)
        appointment_2 = create(:appointment, patient: patient, device_created_at: month_date - 15.days, status: :cancelled)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).previous_appointment_id).to eq(appointment_2.id)
        end
      end
    end

    describe "is_overdue" do
      it "should be no when the previous appointments scheduled date is during the month" do
        patient = create(:patient)
        month_date = june_2021[:now]
        create(:appointment, patient: patient, device_created_at: month_date - 1.month, scheduled_date: month_date)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).is_overdue).to eq("no")
        end
      end

      it "should be yes when the previous appointments scheduled date is in the previous month and the visit date is during the month" do
        patient = create(:patient)
        month_date = june_2021[:now]
        create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)
        create(:blood_pressure, patient: patient, recorded_at: month_date + 1.day)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).is_overdue).to eq("yes")
        end
      end

      it "should be no when the previous appointments scheduled date and visited date is in the previous month and the visit took place after the scheduled date" do
        patient = create(:patient)
        month_date = june_2021[:now]
        create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)
        create(:blood_pressure, patient: patient, recorded_at: month_date - 30.days + 16.days)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).is_overdue).to eq("no")
        end
      end
    end

    describe "has_phone" do
      it "should be yes if the patient has atleast one phone number linked" do
        patient = create(:patient)
        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id).has_phone).to eq("yes")
        end
      end

      it "should be no if the patient has no phone number linked" do
        patient_without_phone_numbers = create(:patient, :with_overdue_appointments, phone_numbers: [])
        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient_without_phone_numbers.id).has_phone).to eq("no")
        end
      end
    end

    describe "has_visited_following_call" do
      it "should be no when there was no visit" do
        patient = create(:patient)
        month_date = june_2021[:now]
        appointment = create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)
        create(:call_result, patient: patient, device_created_at: month_date - 14.days, appointment: appointment)
        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).has_visited_following_call).to eq("no")
        end
      end

      it "should be no when a call was not made" do
        patient = create(:patient)
        month_date = june_2021[:now]
        create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)
        create(:blood_pressure, patient: patient, recorded_at: month_date - 14.days)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).has_visited_following_call).to eq("no")
        end
      end

      it "should be yes when a call was made and the patient visited within 15 days" do
        patient = create(:patient)
        month_date = june_2021[:now]
        appointment = create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)
        create(:call_result, patient: patient, device_created_at: month_date, appointment: appointment)
        create(:blood_pressure, patient: patient, recorded_at: month_date + 4.days)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).has_visited_following_call).to eq("yes")
        end
      end

      it "should be no when a call was made but the patient visited after 15 days of first call" do
        patient = create(:patient)
        month_date = june_2021[:now]
        appointment = create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)
        create(:call_result, patient: patient, device_created_at: month_date, appointment: appointment)
        create(:blood_pressure, patient: patient, recorded_at: month_date + 16.days)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).has_visited_following_call).to eq("no")
        end
      end
    end

    describe "removed_from_overdue_list" do
      it "should be yes when the call result corresponding to the previous appointment is removed_from_overdue_list" do
        patient = create(:patient)
        month_date = june_2021[:now]
        appointment = create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)
        create(:call_result, patient: patient, device_created_at: month_date - 14.days, appointment: appointment,
          result_type: :removed_from_overdue_list, remove_reason: :invalid_phone_number)
        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).removed_from_overdue_list).to eq("yes")
        end
      end

      it "should be no when the call result corresponding to the previous appointment is not removed_from_overdue_list" do
        patient = create(:patient)
        month_date = june_2021[:now]
        appointment = create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)
        create(:call_result, patient: patient, device_created_at: month_date - 14.days, appointment: appointment, result_type: :agreed_to_visit)
        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).removed_from_overdue_list).to eq("no")
        end
      end

      it "should be no when a call was not made after the previous appointment" do
        patient = create(:patient)
        month_date = june_2021[:now]
        create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).removed_from_overdue_list).to eq("no")
        end
      end
    end

    describe "has_called" do
      it "should be yes when a call was made during the month after the previous appointment" do
        patient = create(:patient)
        month_date = june_2021[:now]
        appointment = create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)
        create(:call_result, patient: patient, device_created_at: month_date, appointment: appointment)
        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).has_called).to eq("yes")
        end
      end

      it "should be no when a call was not made during the month after the previous appointment" do
        patient = create(:patient)
        month_date = june_2021[:now]
        create(:appointment, patient: patient, device_created_at: month_date - 30.days, scheduled_date: month_date - 15.days)

        RefreshReportingViews.refresh_v2

        with_reporting_time_zone do
          expect(described_class.find_by(patient_id: patient.id, month_date: month_date).has_called).to eq("no")
        end
      end
    end
  end
end
