# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::TrainingProvider do
  describe 'associations' do
    it { is_expected.to have_many(:trainings) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(256) }
    it { is_expected.to validate_length_of(:description).is_at_most(512) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_length_of(:url).is_at_most(512) }
    it { is_expected.to validate_length_of(:logo_url).is_at_most(512) }
  end

  describe '.for_project' do
    let_it_be(:project) { create(:project) }
    let_it_be(:security_training_provider_1) { create(:security_training_provider) }
    let_it_be(:security_training_provider_2) { create(:security_training_provider) }
    let_it_be(:security_training_provider_3) { create(:security_training_provider) }

    subject { described_class.for_project(project, only_enabled: only_enabled) }

    before_all do
      create(:security_training, :primary, project: project, provider: security_training_provider_1)
      create(:security_training, project: project, provider: security_training_provider_2)
    end

    context 'when the `only_enabled` flag is provided as `false`' do
      let(:only_enabled) { false }

      it { is_expected.to match_array([security_training_provider_1, security_training_provider_2, security_training_provider_3]) }
    end

    context 'when the `only_enabled` flag is provided as `true`' do
      let(:only_enabled) { true }

      it { is_expected.to match_array([security_training_provider_1, security_training_provider_2]) }
    end

    describe 'virtual attributes' do
      let(:only_enabled) { false }

      it 'sets the virtual attributes correctly' do
        is_expected.to match_array([
          an_object_having_attributes(is_primary: true, is_enabled: true),
          an_object_having_attributes(is_primary: false, is_enabled: true),
          an_object_having_attributes(is_primary: false, is_enabled: false)
        ])
      end
    end
  end
end
