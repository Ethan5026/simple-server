class EstimatedPopulation < ApplicationRecord
  belongs_to :region

  validates :population, presence: true, numericality: true
  validates :diagnosis, presence: true

  enum diagnosis: { HTN: "HTN", DM: "DM" }

  validate :can_only_be_set_for_district_or_state
  after_commit :update_state_population

  def can_only_be_set_for_district_or_state
    region_type = region.region_type

    unless region_type == "district" || region_type == "state"
      errors.add(:region, "can only set population for a district or a state")
    end
  end

  def is_population_available_for_all_districts
    # Check if all districts have population set
  end

  def update_state_population
    if region.district_region?
      state = region.state_region
      new_total = state.district_regions.inject(0) {|sum, r| 
        sum += r.reload_estimated_population&.population || 0
      }
      if state.estimated_population
        state.estimated_population.population = new_total
        state.estimated_population.save!
      else
        state.create_estimated_population(population: new_total)
      end
    end
  end
end