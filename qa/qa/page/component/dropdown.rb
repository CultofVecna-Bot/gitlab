# frozen_string_literal: true

module QA
  module Page
    module Component
      module Dropdown
        def select_item(item_text)
          find('li.gl-new-dropdown-item', text: item_text, match: :prefer_exact).click
        end

        def has_item?(item_text)
          has_css?('li.gl-new-dropdown-item', text: item_text, match: :prefer_exact)
        end

        def current_selection
          expand_select_list unless dropdown_open?
          find('span.gl-new-dropdown-button-text').text
        end

        def all_items
          find_all("li.gl-new-dropdown-item").map(&:text)
        end

        def clear_current_selection_if_present
          expand_select_list unless dropdown_open?

          if has_css?('button[data-testid="listbox-reset-button"]')
            find('button[data-testid="listbox-reset-button"]').click
          elsif dropdown_open?
            expand_select_list
          end
        end

        def search_item(item_text)
          QA::Runtime::Logger.info "Searching in dropdown: \"#{item_text}\""

          find('div.gl-listbox-search input[type="Search"]').set(item_text, rapid: false)
          wait_for_search_to_complete
        end

        def send_keys_to_search(item_text)
          find('div.gl-listbox-search input[type="Search"]').send_keys(item_text)
          wait_for_search_to_complete
        end

        def search_and_select(item_text)
          search_item(item_text)

          unless has_item?(item_text)
            raise QA::Page::Base::ElementNotFound, %(Couldn't find option named "#{item_text}")
          end

          select_item(item_text)
        end

        def search_and_select_exact(item_text)
          QA::Runtime::Logger.info "Searching and selecting exact: \"#{item_text}\""

          search_item(item_text)

          unless has_item?(item_text)
            raise QA::Page::Base::ElementNotFound, %(Couldn't find option named "#{item_text}")
          end

          find('li.gl-new-dropdown-item span:nth-child(2)', text: item_text, exact_text: true).click
        end

        def expand_select_list
          find('.gl-new-dropdown-toggle').click
        end

        def wait_for_search_to_complete
          Support::WaitForRequests.wait_for_requests

          has_css?('div[data-testid="listbox-search-loader"]', wait: 1)
          has_no_css?('div[data-testid="listbox-search-loader"]')
        end

        def dropdown_open?
          has_css?('ul.gl-new-dropdown-contents', wait: 1)
        end

        def find_input_by_prefix_and_set(element_prefix, item_text)
          find("input[id^=\"#{element_prefix}\"]").set(item_text)
        end
      end
    end
  end
end
