# frozen_string_literal: true

module QA
  module Page
    module Search
      class Results < QA::Page::Base
        view 'app/views/search/results/_blob_data.html.haml' do
          element :result_item_content
          element :file_title_content
          element :file_text_content
        end

        view 'app/views/shared/projects/_project.html.haml' do
          element 'project-content'
        end

        def switch_to_code
          click_element('nav-item-link', submenu_item: 'Code')
        end

        def switch_to_projects
          switch_to_tab(:projects_tab)
        end

        def has_project_in_search_result?(project_name)
          has_element?(:result_item_content, text: project_name)
        end

        def has_file_in_project?(file_name, project_name)
          within_element(:result_item_content, text: project_name) do
            has_element?(:file_title_content, text: file_name)
          end
        end

        def has_file_in_project_with_content?(file_text, file_path)
          within_element(:result_item_content,
            text: file_path) do
            has_element?(:file_text_content, text: file_text)
          end
        end

        def has_project?(project_name)
          has_element?('project-content', project_name: project_name)
        end

        private

        def switch_to_tab(tab)
          retry_until do
            click_element(tab)
            has_active_element?(tab)
          end
        end
      end
    end
  end
end
