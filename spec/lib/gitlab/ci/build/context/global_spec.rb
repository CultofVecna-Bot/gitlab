# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Build::Context::Global, feature_category: :pipeline_composition do
  let(:pipeline)       { create(:ci_pipeline) }
  let(:yaml_variables) { {} }

  let(:context) { described_class.new(pipeline, yaml_variables: yaml_variables) }

  shared_examples 'variables collection' do
    it { is_expected.to include('CI_COMMIT_REF_NAME' => 'master') }
    it { is_expected.to include('CI_PIPELINE_IID'    => pipeline.iid.to_s) }
    it { is_expected.to include('CI_PROJECT_PATH'    => pipeline.project.full_path) }

    it { is_expected.not_to have_key('CI_JOB_NAME') }

    context 'when FF `ci_remove_legacy_predefined_variables` is disabled' do
      before do
        stub_feature_flags(ci_remove_legacy_predefined_variables: false)
      end

      it { is_expected.not_to have_key('CI_BUILD_REF_NAME') }
    end

    context 'with passed yaml variables' do
      let(:yaml_variables) { [{ key: 'SUPPORTED', value: 'parsed', public: true }] }

      it { is_expected.to include('SUPPORTED' => 'parsed') }
    end
  end

  describe '#variables' do
    subject { context.variables.to_hash }

    it { expect(context.variables).to be_instance_of(Gitlab::Ci::Variables::Collection) }

    it_behaves_like 'variables collection'
  end

  describe '#variables_hash' do
    subject { context.variables_hash }

    it { is_expected.to be_instance_of(ActiveSupport::HashWithIndifferentAccess) }

    it_behaves_like 'variables collection'
  end
end
