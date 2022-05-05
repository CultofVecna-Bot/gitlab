# frozen_string_literal: true

require 'fileutils'

module Gitlab
  module Gfm
    ##
    # Class that rewrites markdown links for uploads
    #
    # Using a pattern defined in `FileUploader` it copies files to a new
    # project and rewrites all links to uploads in a given text.
    #
    #
    class UploadsRewriter
      include Gitlab::Utils::StrongMemoize

      def initialize(text, _text_html, source_project, _current_user)
        @text = text
        @source_project = source_project
        @pattern = FileUploader::MARKDOWN_PATTERN
      end

      def rewrite(target_parent)
        return @text unless needs_rewrite?

        @text.gsub!(@pattern) do |markdown|
          file = find_file($~[:secret], $~[:file])
          # No file will be returned for a path traversal
          next if file.nil?

          break markdown unless file.try(:exists?)

          klass = target_parent.is_a?(Namespace) ? NamespaceFileUploader : FileUploader
          moved = klass.copy_to(file, target_parent)

          moved_markdown = moved.markdown_link

          # Prevents rewrite of plain links as embedded
          if was_embedded?(markdown)
            moved_markdown
          else
            moved_markdown.delete_prefix('!')
          end
        end
      end

      def needs_rewrite?
        strong_memoize(:needs_rewrite) do
          FileUploader::MARKDOWN_PATTERN.match?(@text)
        end
      end

      def was_embedded?(markdown)
        markdown.starts_with?("!")
      end

      def find_file(secret, file_name)
        UploaderFinder.new(@source_project, secret, file_name).execute
      end
    end
  end
end
