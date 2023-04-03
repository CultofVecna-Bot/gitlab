# frozen_string_literal: true

module QA
  module Page
    module Project
      module SubMenus
        module SuperSidebar
          module Plan
            extend QA::Page::PageConcern

            def self.included(base)
              super

              base.class_eval do
                include QA::Page::Project::SubMenus::SuperSidebar::Common
              end
            end

            def go_to_boards
              open_plan_submenu("Issue boards")
            end

            def go_to_service_desk
              open_plan_submenu("Service Desk")
            end

            def go_to_wiki
              open_plan_submenu("Wiki")
            end

            private

            def open_plan_submenu(sub_menu)
              open_submenu("Plan", "#plan", sub_menu)
            end
          end
        end
      end
    end
  end
end
