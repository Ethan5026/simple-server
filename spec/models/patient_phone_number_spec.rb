require 'rails_helper'

RSpec.describe PatientPhoneNumber, type: :model do
  describe 'Validations' do
    it { should validate_presence_of(:created_at) }
    it { should validate_presence_of(:updated_at) }
    it { should validate_presence_of(:number) }
  end

  describe 'Associations' do
    it { should belong_to(:patient) }
  end
end
