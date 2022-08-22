# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Display ultimate feature removal banner', :saas, :js do
  let(:project) { create(:project, :public, :repository) }
  let(:user) { create(:user) }

  before do
    stub_feature_flags(ultimate_feature_removal_banner: true)
    project.add_guest(user)
    project.project_setting.update!(legacy_open_source_license_available: false)
    sign_in(user)
  end

  shared_examples_for 'shows the banner' do
    before do
      visit visit_path
    end

    it "shows the banner message" do
      expect(page).to have_content("Your project is no longer receiving GitLab Ultimate benefits as of 2022-07-01.")
    end

    it "has a link to the FAQ" do
      faq_link = 'https://about.gitlab.com/pricing/faq-efficient-free-tier/#public-projects-on-gitlab-saas-free-tier'
      expect(page).to have_link('FAQ', href: faq_link)
    end
  end

  context 'on project landing page' do
    let(:visit_path) { project_path(project) }

    it_behaves_like "shows the banner"
  end

  context 'on project activity page' do
    let(:visit_path) { activity_project_path(project) }

    it_behaves_like "shows the banner"
  end

  context 'on project labels page' do
    let(:visit_path) { project_labels_path(project) }

    it_behaves_like "shows the banner"
  end

  context 'on project members page' do
    let(:visit_path) { project_project_members_path(project) }

    it_behaves_like "shows the banner"
  end

  context 'on project settings page' do
    let(:visit_path) { edit_project_path(project) }

    before do
      project.add_maintainer(user)
    end

    it_behaves_like "shows the banner"
  end

  context 'on project usage quotas page' do
    let(:visit_path) { project_usage_quotas_path(project) }

    before do
      project.add_maintainer(user)
    end

    it_behaves_like "shows the banner"
  end
end
