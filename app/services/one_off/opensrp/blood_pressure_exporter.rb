require "fhir_models"

module OneOff
  module Opensrp
    class BloodPressureExporter
      attr_reader :blood_pressure

      def initialize(blood_pressure)
        @blood_pressure = blood_pressure
      end

      def encounter_id
        Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, blood_pressure.patient_id + meta.lastUpdated.to_date.iso8601)
      end

      def export
        FHIR::Observation.new(
          meta: meta,
          id: blood_pressure.id,
          identifier: [
            FHIR::Identifier.new(
              value: blood_pressure.id
            )
          ],
          code: FHIR::CodeableConcept.new(
            coding: FHIR::Coding.new(
              system: "http://snomed.info/sct",
              code: "38341003"
            )
          ),
          component: [
            observation_component("271649006", blood_pressure.systolic),
            observation_component("271650006", blood_pressure.diastolic)
          ],
          subject: FHIR::Reference.new(
            reference: "Patient/#{blood_pressure.patient_id}"
          ),
          performer: FHIR::Reference.new(
            reference: "Organization/#{blood_pressure.facility_id}"
          ),
          encounter: FHIR::Reference.new(
            reference: "Encounter/#{encounter_id}"
          ),
          status: "final",
          category: [
            FHIR::CodeableConcept.new(
              coding: [
                FHIR::Coding.new(
                  system: "http://terminology.hl7.org/CodeSystem/observation-category",
                  code: "vital-signs",
                  display: "Vital Signs"
                )
              ]
            )
          ]
        )
      end

      def observation_component(code, value)
        FHIR::Observation::Component.new(
          code: FHIR::CodeableConcept.new(
            coding: [
              FHIR::Coding.new(
                system: "http://snomed.info/sct",
                code: code
              )
            ]
          ),
          valueQuantity: FHIR::Quantity.new(
            value: value,
            unit: "mmHg",
            system: "http://unitsofmeasure.org",
            code: "mm[Hg]"
          )
        )
      end

      def export_encounter
        FHIR::Encounter.new(
          meta: meta,
          status: "finished",
          id: encounter_id,
          identifier: [
            FHIR::Identifier.new(
              value: encounter_id
            )
          ],
          class: FHIR::Coding.new(
            system: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
            code: "AMB"
          ),
          type: [
            FHIR::CodeableConcept.new(
              coding: FHIR::Coding.new(
                system: "http://snomed.info/sct",
                code: "38341003"
              )
            )
          ],
          serviceType: FHIR::CodeableConcept.new(
            coding: [
              FHIR::Coding.new(
                system: "http://terminology.hl7.org/CodeSystem/service-type",
                code: "335"
              )
            ]
          ),
          subject: FHIR::Reference.new(reference: "Patient/#{blood_pressure.patient_id}"),
          period: FHIR::Period.new(start: blood_pressure.recorded_at.iso8601), # TODO: we don't store end period
          reasonCode: [
            FHIR::CodeableConcept.new(
              coding: [
                FHIR::Coding.new(
                  system: "http://snomed.info/sct",
                  code: "1156892006" # TODO
                )
              ]
            )
          ],
          diagnosis: nil,
          location: nil,
          serviceProvider: FHIR::Reference.new(reference: "Organization/#{blood_pressure.facility_id}"),
          partOf: nil
        )
      end

      def meta
        FHIR::Meta.new(
          lastUpdated: blood_pressure.device_updated_at.iso8601,
          tag: [
            FHIR::Coding.new(
              system: "https://smartregister.org/app-version",
              code: "Not defined",
              display: "Application Version"
            ),
            FHIR::Coding.new(
              system: "https://smartregister.org/location-tag-id",
              code: "TODO", # TODO
              display: "Practitioner Location"
            ),
            FHIR::Coding.new(
              system: "https://smartregister.org/organisation-tag-id",
              code: "TODO", # TODO
              display: "Practitioner Organization"
            ),
            FHIR::Coding.new(
              system: "https://smartregister.org/care-team-tag-id",
              code: "TODO", # TODO
              display: "Practitioner CareTeam"
            ),
            FHIR::Coding.new(
              system: "https://smartregister.org/related-entity-location-tag-id",
              code: "TODO",
              display: "Related Entity Location"
            )
          ]
        )
      end
    end
  end
end
