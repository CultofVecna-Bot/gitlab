# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Broadcast Messages', feature_category: :onboarding do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:user) { create(:user) }
  let(:path) { explore_projects_path }

  shared_examples 'a Broadcast Messages' do |type|
    it 'shows broadcast message' do
      visit path

      expect(page).to have_content 'SampleMessage'
    end

    it 'renders styled links' do
      create(:broadcast_message, type, message: "<a href='gitlab.com' style='color: purple'>click me</a>")

      visit path

      expected_html = "<p><a href=\"gitlab.com\" style=\"color: purple\">click me</a></p>"
      expect(page.body).to include(expected_html)
    end
  end

  shared_examples 'a dismissible Broadcast Messages' do
    it 'hides broadcast message after dismiss', :js do
      visit path

      expect_to_be_on_explore_projects_page

      find('body.page-initialised .js-dismiss-current-broadcast-notification').click

      expect_message_dismissed
    end

    it 'broadcast message is still hidden after refresh', :js do
      visit path

      expect_to_be_on_explore_projects_page

      find('body.page-initialised .js-dismiss-current-broadcast-notification').click

      expect_message_dismissed

      visit path

      expect_message_dismissed
    end
  end

  describe 'banner type' do
    let_it_be(:broadcast_message) { create(:broadcast_message, message: 'SampleMessage') }

    it_behaves_like 'a Broadcast Messages'

    it 'is not dismissible' do
      visit path

      expect(page).not_to have_selector('.js-dismiss-current-broadcast-notification')
    end

    it 'does not replace placeholders' do
      create(:broadcast_message, message: 'Hi {{name}}')

      gitlab_sign_in(user)

      visit path

      expect(page).to have_content 'Hi {{name}}'
    end
  end

  describe 'dismissible banner type' do
    let_it_be(:broadcast_message) { create(:broadcast_message, dismissable: true, message: 'SampleMessage') }

    it_behaves_like 'a Broadcast Messages'

    it_behaves_like 'a dismissible Broadcast Messages'
  end

  describe 'notification type' do
    let_it_be(:broadcast_message) { create(:broadcast_message, :notification, message: 'SampleMessage') }

    it_behaves_like 'a Broadcast Messages', :notification

    it_behaves_like 'a dismissible Broadcast Messages'

    it 'replaces placeholders' do
      create(:broadcast_message, :notification, message: 'Hi {{name}}')

      gitlab_sign_in(user)

      visit path

      expect(page).to have_content "Hi #{user.name}"
    end
  end

  context 'with GitLab revision changes', :js, :use_clean_rails_redis_caching do
    it 'properly shows effects of delete from any revision' do
      text = 'my_broadcast_message'
      message = create(:broadcast_message, broadcast_type: :banner, message: text)
      new_strategy_value = { revision: 'abc123', version: '_version_' }

      visit path

      expect_broadcast_message(text)

      # seed the other cache
      original_strategy_value = Gitlab::Cache::JsonCache::STRATEGY_KEY_COMPONENTS
      stub_const('Gitlab::Cache::JsonCaches::JsonKeyed::STRATEGY_KEY_COMPONENTS', new_strategy_value)

      page.refresh

      expect_broadcast_message(text)

      # delete on original cache
      stub_const('Gitlab::Cache::JsonCaches::JsonKeyed::STRATEGY_KEY_COMPONENTS', original_strategy_value)
      admin = create(:admin)
      sign_in(admin)
      gitlab_enable_admin_mode_sign_in(admin)

      visit admin_broadcast_messages_path

      page.within('[data-testid="message-row"]', match: :first) do
        find("[data-testid='delete-message-#{message.id}']").click
      end

      accept_gl_confirm(button_text: 'Delete message')

      visit path

      expect_no_broadcast_message

      # other revision of GitLab does gets cache destroyed
      stub_const('Gitlab::Cache::JsonCaches::JsonKeyed::STRATEGY_KEY_COMPONENTS', new_strategy_value)

      page.refresh

      expect_no_broadcast_message
    end
  end

  def expect_broadcast_message(text)
    page.within('[data-testid="banner-broadcast-message"]') do
      expect(page).to have_content text
    end
  end

  def expect_no_broadcast_message
    expect_to_be_on_explore_projects_page

    expect(page).not_to have_selector('[data-testid="banner-broadcast-message"]')
  end

  def expect_to_be_on_explore_projects_page
    page.within('[data-testid="explore-projects-title"]') do
      expect(page).to have_content 'Explore projects'
    end
  end

  def expect_message_dismissed
    expect(page).not_to have_content 'SampleMessage'
  end
end
