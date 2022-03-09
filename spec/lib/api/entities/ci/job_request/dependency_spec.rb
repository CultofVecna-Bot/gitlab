# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Ci::JobRequest::Dependency do
  let(:job) { create(:ci_build, :artifacts) }
  let(:entity) { described_class.new(job) }

  subject { entity.as_json }

  it 'returns the dependency id' do
    expect(subject[:id]).to eq(job.id)
  end

  it 'returns the dependency name' do
    expect(subject[:name]).to eq(job.name)
  end

  it 'returns the dependency token' do
    expect(subject[:token]).to eq(job.token)
  end

  it 'returns the dependency artifacts_file', :aggregate_failures do
    expect(subject[:artifacts_file][:filename]).to eq('ci_build_artifacts.zip')
    expect(subject[:artifacts_file][:size]).to eq(job.artifacts_size)
  end
end
