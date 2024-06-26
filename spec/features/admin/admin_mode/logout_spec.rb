# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin Mode Logout', :js, feature_category: :system_access do
  include TermsHelper
  include UserLoginHelper

  let(:user) { create(:admin) }

  before do
    # TODO: This used to use gitlab_sign_in, instead of sign_in, but that is buggy.  See
    #   this issue to look into why: https://gitlab.com/gitlab-org/gitlab/-/issues/331851
    sign_in(user)
    gitlab_enable_admin_mode_sign_in(user, use_mock_admin_mode: false)
    visit admin_root_path
  end

  it 'disable removes admin mode and redirects to root page' do
    gitlab_disable_admin_mode

    expect(page).to have_current_path root_path, ignore_query: true

    click_button 'Search or go to…'

    expect(page).to have_link(href: new_admin_session_path)
  end

  it 'disable shows flash notice' do
    gitlab_disable_admin_mode

    expect(page).to have_selector('[data-testid="alert-info"]')
  end

  context 'on a read-only instance' do
    before do
      allow(Gitlab::Database).to receive(:read_only?).and_return(true)
    end

    it 'disable removes admin mode and redirects to root page' do
      gitlab_disable_admin_mode

      expect(page).to have_current_path root_path, ignore_query: true

      click_button 'Search or go to…'

      expect(page).to have_link(href: new_admin_session_path)
    end
  end
end
