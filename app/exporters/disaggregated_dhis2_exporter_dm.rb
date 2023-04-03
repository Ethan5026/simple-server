class DisaggregatedDhis2ExporterDM
    STEP = 5
    BUCKETS = (15..75).step(STEP).to_a

    def self.export
        exporter = Dhis2Exporter.new(

            facility_identifier:FacilityBusinessIdentifier.dhis2_org_unit_id,
            periods: (current_month_period.advance(months: -24)..current_month_period),
            data_elements_map: CountryConfig.current.fetch(:disaggregated_dhis2_data_elements)

        )

        exporter.export do | facility_identifier,period|
            region = facility_identifier.facility.region
            {

                dm_cumulative_assigned_patients: cleanup(disaggregated_counts(PatientStates::CumulativeAssignedPatientsQueryDM).new(
                    region, period
                  ))),

                
                dm_controlled_patients: cleanup(disaggregated_counts(PatientStates:: ControlledPatientsQueryDM.new(region,
                    period))),

                dm_uncontrolled_patients: cleanup(disaggregated_counts(PatientStates::UncontrolledPatientsQueryDM.new(region,
                                                                                                             period))),
                dm_patients_who_missed_visits: cleanup(disaggregated_counts(PatientStates:::MissedVisitsPatientsQueryDM.new(
                                                                       region, period
                                                                     ))),
                dm_patients_lost_to_follow_up: cleanup(disaggregated_counts(PatientStates::LostToFollowUpPatientsQueryDM.new(
                                                                       region, period
                                                                     ))),
                dm_dead_patients: cleanup(disaggregated_counts(PatientStates::DeadPatientsQuery.new(region, period))),
        
                dm_cumulative_registered_patients: cleanup(disaggregated_counts(PatientStates::CumulativeRegistrationsQueryDM.new(
                                                                           region, period
                                                                         ))),

                dm_monthly_registered_patients: cleanup(disaggregated_counts(PatientStates::MonthlyRegistrationsQuery.new(
                                                                        region, period
                                                                      ))),
                dm_cumulative_assigned_patients_adjusted: PatientStates::DisaggregatedPatientCountQuery.disaggregate_by_age(
          
                    BUCKETS,
          
                    PatientStates::DisaggregatedPatientCountQuery.disaggregate_by_gender(
                      PatientStates::CumulativeAssignedPatientsQuery.new(region, period).excluding_recent_registrations
          )
        ).count
      }
    end
  end

  def self.disaggregated_counts(query)
    PatientStates::DisaggregatedPatientCountQuery.disaggregate_by_age(
      BUCKETS,
      PatientStates::DisaggregatedPatientCountQuery.disaggregate_by_gender(
        query.call
      )
    ).count
  end

  def self.cleanup(disaggregated_values)
    disaggregated_values.transform_keys do |disaggregated_counts_key|
      disaggregated_counts_key[0] +
        '_' +
        BUCKETS[disaggregated_counts_key[1] - 1].to_s +
        '_' +
        (BUCKETS[disaggregated_counts_key[1] - 1] + STEP - 1).to_s
    end
  end

  def self.current_month_period
    @current_month_period ||= Period.current.previous
  end
end

                

                

