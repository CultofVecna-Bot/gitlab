# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::OnDemandScansHelper do
  describe '#on_demand_scans_form_data' do
    let_it_be(:project) { create(:project) }
    let_it_be(:timezones) { [{ identifier: "Europe/Paris" }] }

    before do
      allow(project).to receive(:default_branch).and_return("default-branch")
      allow(project).to receive(:path_with_namespace).and_return("foo/bar")
      allow(helper).to receive(:timezone_data).with(format: :full).and_return(timezones)
    end

    it 'returns proper data' do
      expect(helper.on_demand_scans_form_data(project)).to match(
        'help-page-path' => "/help/user/application_security/dast/index#on-demand-scans",
        'empty-state-svg-path' => match_asset_path('/assets/illustrations/empty-state/ondemand-scan-empty.svg'),
        'default-branch' => "default-branch",
        'project-path' => "foo/bar",
        'profiles-library-path' => "/#{project.full_path}/-/security/configuration/dast_scans",
        'scanner-profiles-library-path' => "/#{project.full_path}/-/security/configuration/dast_scans#scanner-profiles",
        'site-profiles-library-path' => "/#{project.full_path}/-/security/configuration/dast_scans#site-profiles",
        'new-scanner-profile-path' => "/#{project.full_path}/-/security/configuration/dast_scans/dast_scanner_profiles/new",
        'new-site-profile-path' => "/#{project.full_path}/-/security/configuration/dast_scans/dast_site_profiles/new",
        'timezones' => timezones.to_json
      )
    end
  end
end
