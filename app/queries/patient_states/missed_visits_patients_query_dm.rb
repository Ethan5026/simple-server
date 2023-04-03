class PatientStates::MissedVisitsPatientsQueryDM
    attr_reader :region, :period
  
    def initialize(region, period)
      @region = region
      @period = period
    end
  
    def call
      PatientStates:: CumulativeAssignedPatientsQueryDM.new(region, period)
        .excluding_recent_registrations
        .where(htn_care_state: "under_care")
        .where(diabetes_treatment_outcome_in_last_3_months: "missed_visit")
    end
  end
  
  
  