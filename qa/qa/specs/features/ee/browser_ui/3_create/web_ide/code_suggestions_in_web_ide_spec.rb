# frozen_string_literal: true

module QA
  # These tests require several feature flags, user settings, and instance configuration that will require substantial
  # effort to fully automate. In the meantime the following were done manually so we can run the tests against
  # gitlab.com with the `gitlab-qa` user:
  # 1. Enable the code_suggestions_completion_api feature flag
  #    ```/chatops run feature set --user=gitlab-qa code_suggestions_completion_api true```
  #    ```/chatops run feature set --user=gitlab-qa code_suggestions_completion_api true --staging```
  # 2. Enable the Code Suggestions user preference
  #    See https://docs.gitlab.com/ee/user/project/repository/code_suggestions.html#enable-code-suggestions-for-an-individual-user
  RSpec.describe 'Create',
    only: { pipeline: %i[staging staging-canary canary production] }, product_group: :ide do
    describe 'Code Suggestions in Web IDE' do
      let(:project) { create(:project, :with_readme, name: 'webide-code-suggestions-project') }
      let(:file_name) { 'new_file.rb' }
      let(:prompt_data) { 'def reverse_string' }
      let(:prompt_regex) { /#{prompt_data}\(\S+\)/ }

      before do
        Flow::Login.sign_in

        Resource::Repository::Commit.fabricate_via_api! do |commit|
          commit.project = project
          commit.add_files(
            [
              {
                file_path: file_name,
                content: '# test'
              }
            ])
        end
        project.visit!
        Page::Project::Show.perform(&:open_web_ide!)
        Page::Project::WebIDE::VSCode.perform(&:wait_for_ide_to_load)
      end

      it(
        'adds text into a file and verifies code suggestions appear',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/425756',
        quarantine: {
          type: :investigating,
          issue: "https://gitlab.com/gitlab-org/gitlab/-/issues/427737"
        }
      ) do
        Page::Project::WebIDE::VSCode.perform do |ide|
          ide.within_vscode_editor do
            ide.open_file_from_explorer(file_name)
            ide.add_file_content(prompt_data)
            ide.verify_prompt_appears_and_accept(prompt_regex)

            expect(ide.validate_prompt(prompt_regex)).to eq true
          end
        end
      end
    end
  end
end
