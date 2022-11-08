# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, :yaml_processor_feature_flag_corectness do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user)    { project.first_owner }

  let(:service)  { described_class.new(project, user, { ref: 'master' }) }
  let(:pipeline) { service.execute(:push).payload }

  before do
    stub_ci_pipeline_yaml_file(config)
  end

  context 'when using variables' do
    context 'when variables have expand: true/false' do
      let(:config) do
        <<-YAML
        variables:
          VAR7:
            value: "value 7 $CI_PIPELINE_ID"
            expand: false
          VAR8:
            value: "value 8 $CI_PIPELINE_ID"
            expand: false

        rspec:
          script: rspec
          variables:
            VAR1: "JOBID-$CI_JOB_ID"
            VAR2: "PIPELINEID-$CI_PIPELINE_ID and $VAR1"
            VAR3:
              value: "PIPELINEID-$CI_PIPELINE_ID and $VAR1"
              expand: false
            VAR4:
              value: "JOBID-$CI_JOB_ID"
              expand: false
            VAR5: "PIPELINEID-$CI_PIPELINE_ID and $VAR4"
            VAR6:
              value: "PIPELINEID-$CI_PIPELINE_ID and $VAR4"
              expand: false
            VAR7: "overridden value 7 $CI_PIPELINE_ID"
        YAML
      end

      let(:rspec) { find_job('rspec') }

      it 'creates the pipeline with a job that has variable expanded according to "expand"' do
        expect(pipeline).to be_created_successfully

        expect(Ci::BuildRunnerPresenter.new(rspec).runner_variables).to include(
          { key: 'VAR1', value: "JOBID-#{rspec.id}", public: true, masked: false },
          { key: 'VAR2', value: "PIPELINEID-#{pipeline.id} and JOBID-#{rspec.id}", public: true, masked: false },
          { key: 'VAR3', value: "PIPELINEID-$CI_PIPELINE_ID and $VAR1", public: true, masked: false, raw: true },
          { key: 'VAR4', value: "JOBID-$CI_JOB_ID", public: true, masked: false, raw: true },
          { key: 'VAR5', value: "PIPELINEID-#{pipeline.id} and $VAR4", public: true, masked: false },
          { key: 'VAR6', value: "PIPELINEID-$CI_PIPELINE_ID and $VAR4", public: true, masked: false, raw: true },
          { key: 'VAR7', value: "overridden value 7 #{pipeline.id}", public: true, masked: false },
          { key: 'VAR8', value: "value 8 $CI_PIPELINE_ID", public: true, masked: false, raw: true }
        )
      end

      context 'when the FF ci_raw_variables_in_yaml_config is disabled' do
        before do
          stub_feature_flags(ci_raw_variables_in_yaml_config: false)
        end

        it 'creates the pipeline with a job that has all variables expanded' do
          expect(pipeline).to be_created_successfully

          expect(Ci::BuildRunnerPresenter.new(rspec).runner_variables).to include(
            { key: 'VAR1', value: "JOBID-#{rspec.id}", public: true, masked: false },
            { key: 'VAR2', value: "PIPELINEID-#{pipeline.id} and JOBID-#{rspec.id}", public: true, masked: false },
            { key: 'VAR3', value: "PIPELINEID-#{pipeline.id} and JOBID-#{rspec.id}", public: true, masked: false },
            { key: 'VAR4', value: "JOBID-#{rspec.id}", public: true, masked: false },
            { key: 'VAR5', value: "PIPELINEID-#{pipeline.id} and JOBID-#{rspec.id}", public: true, masked: false },
            { key: 'VAR6', value: "PIPELINEID-#{pipeline.id} and JOBID-#{rspec.id}", public: true, masked: false },
            { key: 'VAR7', value: "overridden value 7 #{pipeline.id}", public: true, masked: false },
            { key: 'VAR8', value: "value 8 #{pipeline.id}", public: true, masked: false }
          )
        end
      end
    end
  end

  private

  def find_job(name)
    pipeline.processables.find { |job| job.name == name }
  end
end
