# frozen_string_literal: true

require 'spec_helper'

# See https://docs.gitlab.com/ee/development/gitlab_flavored_markdown/specification_guide/#markdown-snapshot-testing
# for documentation on this spec.
RSpec.shared_context 'with API::Markdown Snapshot shared context' do |glfm_specification_dir|
  include ApiHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:api_url) { api('/markdown', user) }

  before do
    # Set 'GITLAB_TEST_FOOTNOTE_ID' in order to override random number generation in
    # Banzai::Filter::FootnoteFilter#random_number, and thus avoid the need to
    # perform normalization on the value. See:
    # https://docs.gitlab.com/ee/development/gitlab_flavored_markdown/specification_guide/#normalization
    stub_env('GITLAB_TEST_FOOTNOTE_ID', 42)
  end

  markdown_examples, html_examples = %w[markdown.yml html.yml].map do |file_name|
    yaml = File.read("#{glfm_specification_dir}/example_snapshots/#{file_name}")
    YAML.safe_load(yaml, symbolize_names: true, aliases: true)
  end

  normalizations_yaml = File.read(
    "#{glfm_specification_dir}/input/gitlab_flavored_markdown/glfm_example_normalizations.yml")
  normalizations_by_example_name = YAML.safe_load(normalizations_yaml, symbolize_names: true, aliases: true)

  if (focused_markdown_examples_string = ENV['FOCUSED_MARKDOWN_EXAMPLES'])
    focused_markdown_examples = focused_markdown_examples_string.split(',').map(&:strip).map(&:to_sym)
    markdown_examples.select! { |example_name| focused_markdown_examples.include?(example_name) }
  end

  markdown_examples.each do |name, markdown|
    context "for #{name}" do
      let(:html) { html_examples.fetch(name).fetch(:static) }
      let(:normalizations) { normalizations_by_example_name.dig(name, :html, :static, :snapshot) }

      it "verifies conversion of GLFM to HTML", :unlimited_max_formatted_output_length do
        # noinspection RubyResolve
        normalized_html = normalize_html(html, normalizations)

        post api_url, params: { text: markdown, gfm: true }
        expect(response).to be_successful
        parsed_response = Gitlab::Json.parse(response.body, symbolize_names: true)
        # Some responses have the HTML in the `html` key, others in the `body` key.
        response_html = parsed_response[:body] || parsed_response[:html]
        normalized_response_html = normalize_html(response_html, normalizations)

        expect(normalized_response_html).to eq(normalized_html)
      end

      def normalize_html(html, normalizations)
        return html unless normalizations

        normalized_html = html.dup
        normalizations.each_value do |normalization_entry|
          normalization_entry.each do |normalization|
            regex = normalization.fetch(:regex)
            replacement = normalization.fetch(:replacement)
            normalized_html.gsub!(%r{#{regex}}, replacement)
          end
        end

        normalized_html
      end
    end
  end
end
