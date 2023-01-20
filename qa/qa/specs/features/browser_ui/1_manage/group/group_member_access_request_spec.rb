# frozen_string_literal: true

module QA
  RSpec.describe 'Manage', :requires_admin, product_group: :organization do
    describe 'Group member access request' do
      let!(:admin_api_client) { Runtime::API::Client.as_admin }

      let!(:user) do
        Resource::User.fabricate_via_api! do |user|
          user.api_client = admin_api_client
        end
      end

      let!(:group) do
        Resource::Group.fabricate_via_api! do |group|
          group.path = "group-for-access-request-#{SecureRandom.hex(8)}"
          group.api_client = admin_api_client
        end
      end

      before do
        Flow::Login.sign_in(as: user)
        group.visit!

        Page::Group::Show.perform(&:click_request_access)

        Flow::Login.sign_in_as_admin

        Page::Main::Menu.perform do |menu|
          menu.go_to_page_by_shortcut(:todos_shortcut_button)
        end

        Page::Dashboard::Todos.perform do |todos|
          todos.filter_todos_by_group(group)
        end
      end

      after do
        user&.remove_via_api!
      end

      it 'generates a todo item for the group owner',
         testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/370132' do
        Page::Dashboard::Todos.perform do |todos|
          expect(todos).to have_latest_todo_with_author(
            author: user.name,
            action: "has requested access to group #{group.path}"
          )
        end
      end

      context 'when managing requests as the group owner' do
        before do
          Page::Dashboard::Todos.perform do |todos|
            todos.click_todo_with_content(group.name)
          end
        end

        context 'and request is accepted' do
          before do
            Page::Group::Members.perform do |members|
              members.approve_access_request(user.username)
            end
          end

          it 'adds user to the group',
             testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/386792' do
            found_member = group.reload!.find_member(user.username)

            expect(found_member).not_to be_nil
            expect(found_member.fetch(:access_level))
              .to eq(Resource::Members::AccessLevel::DEVELOPER)
          end
        end

        context 'and request is denied' do
          before do
            Page::Group::Members.perform do |members|
              members.deny_access_request(user.username)
            end
          end

          it 'does not add user to the group',
             testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/386793' do
            found_member = group.reload!.find_member(user.username)

            expect(found_member).to be_nil
          end
        end
      end
    end
  end
end
