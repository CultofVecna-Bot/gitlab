# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Discussion Lock', :js, feature_category: :team_planning do
  let(:user) { create(:user) }
  let(:issue) { create(:issue, project: project, author: user) }
  let(:project) { create(:project, :public) }

  before do
    sign_in(user)
    stub_feature_flags(moved_mr_sidebar: false)
  end

  context 'when a user is a team member' do
    before do
      project.add_developer(user)
    end

    context 'when the discussion is unlocked' do
      it 'the user can lock the issue' do
        visit project_issue_path(project, issue)

        expect(find('.issuable-sidebar')).to have_content('Unlocked')

        page.within('.issuable-sidebar') do
          find('.lock-edit').click
          click_button('Lock')
        end

        expect(find('#notes')).to have_content('locked the discussion in this issue')
      end
    end

    context 'when the discussion is locked' do
      before do
        issue.update_attribute(:discussion_locked, true)
        visit project_issue_path(project, issue)
      end

      it 'the user can unlock the issue' do
        expect(find('.issuable-sidebar')).to have_content('Locked')

        page.within('.issuable-sidebar') do
          find('.lock-edit').click
          click_button('Unlock')
        end

        expect(find('#notes')).to have_content('unlocked the discussion in this issue')
        expect(find('.issuable-sidebar')).to have_content('Unlocked')
      end

      it 'the user can create a comment' do
        page.within('#notes .js-main-target-form') do
          fill_in 'note[note]', with: 'Some new comment'
          click_button 'Comment'
        end

        wait_for_requests

        expect(find('div#notes')).to have_content('Some new comment')
      end
    end
  end

  context 'when a user is not a team member' do
    context 'when the discussion is unlocked' do
      before do
        visit project_issue_path(project, issue)
      end

      it 'the user can not lock the issue' do
        expect(find('.issuable-sidebar')).to have_content('Unlocked')
        expect(find('.issuable-sidebar')).not_to have_selector('.lock-edit')
      end

      it 'the user can create a comment' do
        page.within('#notes .js-main-target-form') do
          fill_in 'note[note]', with: 'Some new comment'
          click_button 'Comment'
        end

        wait_for_requests

        expect(find('div#notes')).to have_content('Some new comment')
      end
    end

    context 'when the discussion is locked' do
      before do
        issue.update_attribute(:discussion_locked, true)
        visit project_issue_path(project, issue)
      end

      it 'the user can not unlock the issue' do
        expect(find('.issuable-sidebar')).to have_content('Locked')
        expect(find('.issuable-sidebar')).not_to have_selector('.lock-edit')
      end

      it 'the user can not create a comment' do
        page.within('#notes') do
          expect(page).not_to have_selector('js-main-target-form')
          expect(find_by_testid('disabled-comments'))
            .to have_content('The discussion in this issue is locked. Only project members can comment.')
        end
      end
    end
  end
end
