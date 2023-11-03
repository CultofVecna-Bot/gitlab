# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mini Pipeline Graph in Commit View', :js, feature_category: :source_code_management do
  let(:project) { create(:project, :public, :repository) }

  context 'when commit has pipelines and feature flag is enabled' do
    let(:pipeline) do
      create(
        :ci_pipeline,
        status: :running,
        project: project,
        ref: project.default_branch,
        sha: project.commit.sha
      )
    end

    let(:build) { create(:ci_build, pipeline: pipeline, status: :running) }

    before do
      build.run
      visit project_commit_path(project, project.commit.id)
      wait_for_requests
    end

    it 'displays the graphql pipeline stage' do
      expect(page).to have_selector('[data-testid="pipeline-stage"]')

      build.drop
    end
  end

  context 'when commit has pipelines and feature flag is disabled' do
    let(:pipeline) do
      create(
        :ci_pipeline,
        status: :running,
        project: project,
        ref: project.default_branch,
        sha: project.commit.sha
      )
    end

    let(:build) { create(:ci_build, pipeline: pipeline, status: :running) }

    before do
      stub_feature_flags(ci_graphql_pipeline_mini_graph: false)
      build.run
      visit project_commit_path(project, project.commit.id)
      wait_for_requests
    end

    it 'display icon with status' do
      expect(page).to have_selector('[data-testid="status_running_borderless-icon"]')
    end

    it 'displays a mini pipeline graph' do
      expect(page).to have_selector('[data-testid="commit-box-pipeline-mini-graph"]')

      first('[data-testid="mini-pipeline-graph-dropdown"]').click

      wait_for_requests

      page.within '.js-builds-dropdown-list' do
        expect(page).to have_selector('[data-testid="status_running_borderless-icon"]')
        expect(page).to have_content(build.stage_name)
      end

      build.drop
    end
  end

  context 'when commit does not have pipelines' do
    before do
      visit project_commit_path(project, project.commit.id)
    end

    it 'does not display a mini pipeline graph' do
      expect(page).not_to have_selector('[data-testid="pipeline-mini-graph"]')
    end
  end
end
