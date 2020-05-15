# frozen_string_literal: true

module QA
  module Page
    module Component
      module DesignManagement
        def self.prepended(page)
          page.module_eval do
            view 'app/assets/javascripts/design_management/components/design_notes/design_discussion.vue' do
              element :design_discussion_content
            end

            view 'app/assets/javascripts/design_management/components/design_notes/design_note.vue' do
              element :note_content
            end

            view 'app/assets/javascripts/design_management/components/design_notes/design_reply_form.vue' do
              element :note_textarea
              element :save_comment_button
            end

            view 'app/assets/javascripts/design_management/components/design_overlay.vue' do
              element :design_image_button
            end

            view 'app/assets/javascripts/design_management/components/list/item.vue' do
              element :design_file_name
              element :design_image
            end
          end
        end

        def add_annotation(note)
          click_element(:design_image_button)
          fill_element(:note_textarea, note)
          click_element(:save_comment_button)

          # It takes a moment for the annotation to be saved.
          # We'll check for the annotation in a test, but here we'll at least
          # wait for the "Save comment" button to disappear
          saved = has_no_element?(:save_comment_button)

          raise ExpectationNotMet, %q(There was a problem while adding the annotation) unless saved
        end

        def add_design(design_file_path)
          # `attach_file` doesn't seem able to find element via data attributes.
          # It accepts a `class:` option, but that only works for class attributes
          # It doesn't work as a CSS selector.
          # So instead we use the name attribute as a locator
          page.attach_file("design_file", design_file_path, make_visible: { display: 'block' })

          filename = ::File.basename(design_file_path)

          found = wait_until(reload: false, sleep_interval: 1) do
            image = find_element(:design_image)

            has_element?(:design_file_name, text: filename) &&
              image["complete"] &&
              image["naturalWidth"].to_i > 0
          end

          raise ElementNotFound, %Q(Attempted to attach design "#{filename}" but it did not appear) unless found
        end

        def click_design(filename)
          click_element(:design_file_name, text: filename)
        end

        def has_annotation?(note)
          within_element_by_index(:design_discussion_content, 0) do
            has_element?(:note_content, text: note)
          end
        end
      end
    end
  end
end
