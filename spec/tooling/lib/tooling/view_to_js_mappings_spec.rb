# frozen_string_literal: true

require 'tempfile'
require_relative '../../../../tooling/lib/tooling/view_to_js_mappings'

RSpec.describe Tooling::ViewToJsMappings, feature_category: :tooling do
  # We set temporary folders, and those readers give access to those folder paths
  attr_accessor :view_base_folder, :js_base_folder

  around do |example|
    Dir.mktmpdir do |tmp_js_base_folder|
      Dir.mktmpdir do |tmp_views_base_folder|
        self.js_base_folder   = tmp_js_base_folder
        self.view_base_folder = tmp_views_base_folder

        example.run
      end
    end
  end

  describe '#execute' do
    let(:instance) do
      described_class.new(
        view_base_folder: view_base_folder,
        js_base_folder: js_base_folder
      )
    end

    let(:changed_files) { %W[#{view_base_folder}/index.html] }

    subject { instance.execute(changed_files) }

    context 'when no view files have been changed' do
      before do
        allow(instance).to receive(:view_files).and_return([])
      end

      it 'returns nothing' do
        expect(subject).to match_array([])
      end
    end

    context 'when some view files have been changed' do
      before do
        File.write("#{view_base_folder}/index.html", index_html_content)
      end

      context 'when they do not contain the HTML attribute value we search for' do
        let(:index_html_content) do
          <<~FILE
            Beginning of file
            End of file
          FILE
        end

        it 'returns nothing' do
          expect(subject).to match_array([])
        end
      end

      context 'when they contain the HTML attribute value we search for' do
        let(:index_html_content) do
          <<~FILE
            Beginning of file

            <a id="js-some-id">A link</a>

            End of file
          FILE
        end

        context 'when no matching JS files are found' do
          it 'returns nothing' do
            expect(subject).to match_array([])
          end
        end

        context 'when some matching JS files are found' do
          let(:index_js_content) do
            <<~FILE
              Beginning of file

              const isMainAwardsBlock = votesBlock.closest('#js-some-id.some_class').length;

              End of file
            FILE
          end

          before do
            File.write("#{js_base_folder}/index.js", index_js_content)
          end

          it 'returns the matching JS files' do
            expect(subject).to match_array(["#{js_base_folder}/index.js"])
          end
        end
      end
    end

    context 'when rails partials are included in the file' do
      before do
        File.write("#{view_base_folder}/index.html", index_html_content)
        File.write("#{view_base_folder}/_my-partial.html.haml", partial_file_content)
        File.write("#{js_base_folder}/index.js", index_js_content)
      end

      let(:index_html_content) do
        <<~FILE
          Beginning of file

          = render 'my-partial'

          End of file
        FILE
      end

      let(:partial_file_content) do
        <<~FILE
          Beginning of file

          <a class="js-some-class">A link with class</a>

          End of file
        FILE
      end

      let(:index_js_content) do
        <<~FILE
          Beginning of file

          const isMainAwardsBlock = votesBlock.closest('.js-some-class').length;

          End of file
        FILE
      end

      it 'scans those partials for the HTML attribute value' do
        expect(subject).to match_array(["#{js_base_folder}/index.js"])
      end
    end
  end

  describe '#view_files' do
    subject { described_class.new(view_base_folder: view_base_folder).view_files(changed_files) }

    context 'when no files were changed' do
      let(:changed_files) { [] }

      it 'returns an empty array' do
        expect(subject).to match_array([])
      end
    end

    context 'when no view files were changed' do
      let(:changed_files) { ["#{js_base_folder}/index.js"] }

      it 'returns an empty array' do
        expect(subject).to match_array([])
      end
    end

    context 'when view files were changed' do
      let(:changed_files) { ["#{js_base_folder}/index.js", "#{view_base_folder}/index.html"] }

      it 'returns the path to the view files' do
        expect(subject).to match_array(["#{view_base_folder}/index.html"])
      end
    end
  end

  describe '#folders_for_available_editions' do
    let(:base_folder_path) { 'app/views' }

    subject { described_class.new.folders_for_available_editions(base_folder_path) }

    context 'when FOSS' do
      before do
        allow(GitlabEdition).to receive(:ee?).and_return(false)
        allow(GitlabEdition).to receive(:jh?).and_return(false)
      end

      it 'returns the correct paths' do
        expect(subject).to match_array([base_folder_path])
      end
    end

    context 'when EE' do
      before do
        allow(GitlabEdition).to receive(:ee?).and_return(true)
        allow(GitlabEdition).to receive(:jh?).and_return(false)
      end

      it 'returns the correct paths' do
        expect(subject).to eq([base_folder_path, "ee/#{base_folder_path}"])
      end
    end

    context 'when JiHu' do
      before do
        allow(GitlabEdition).to receive(:ee?).and_return(true)
        allow(GitlabEdition).to receive(:jh?).and_return(true)
      end

      it 'returns the correct paths' do
        expect(subject).to eq([base_folder_path, "ee/#{base_folder_path}", "jh/#{base_folder_path}"])
      end
    end
  end

  describe '#find_partials' do
    subject { described_class.new(view_base_folder: view_base_folder).find_partials(file_path) }

    let(:file_path) { "#{view_base_folder}/my_html_file.html" }

    before do
      File.write(file_path, file_content)
    end

    context 'when the file includes a partial' do
      context 'when the partial is in the same folder as the view file' do
        before do
          File.write("#{view_base_folder}/_my-partial.html.haml", 'Hello from partial')
        end

        let(:file_content) do
          <<~FILE
            Beginning of file

            = render "my-partial"

            End of file
          FILE
        end

        it "returns the partial file path" do
          expect(subject).to match_array(["#{view_base_folder}/_my-partial.html.haml"])
        end
      end

      context 'when the partial is in a subfolder' do
        before do
          FileUtils.mkdir_p("#{view_base_folder}/subfolder")

          (1..12).each do |i|
            FileUtils.touch "#{view_base_folder}/subfolder/_my-partial#{i}.html.haml"
          end
        end

        let(:file_content) do
          <<~FILE
            Beginning of file

            = render("subfolder/my-partial1")
            = render "subfolder/my-partial2"
            = render(partial: "subfolder/my-partial3")
            = render partial: "subfolder/my-partial4"
            = render(partial:"subfolder/my-partial5", path: 'else')
            = render partial:"subfolder/my-partial6"
            = render_if_exist("subfolder/my-partial7", path: 'else')
            = render_if_exist "subfolder/my-partial8"
            = render_if_exist(partial: "subfolder/my-partial9", path: 'else')
            = render_if_exist partial: "subfolder/my-partial10"
            = render_if_exist(partial:"subfolder/my-partial11", path: 'else')
            = render_if_exist partial:"subfolder/my-partial12"

            End of file
          FILE
        end

        it "returns the partials file path" do
          expect(subject).to match_array([
            "#{view_base_folder}/subfolder/_my-partial1.html.haml",
            "#{view_base_folder}/subfolder/_my-partial2.html.haml",
            "#{view_base_folder}/subfolder/_my-partial3.html.haml",
            "#{view_base_folder}/subfolder/_my-partial4.html.haml",
            "#{view_base_folder}/subfolder/_my-partial5.html.haml",
            "#{view_base_folder}/subfolder/_my-partial6.html.haml",
            "#{view_base_folder}/subfolder/_my-partial7.html.haml",
            "#{view_base_folder}/subfolder/_my-partial8.html.haml",
            "#{view_base_folder}/subfolder/_my-partial9.html.haml",
            "#{view_base_folder}/subfolder/_my-partial10.html.haml",
            "#{view_base_folder}/subfolder/_my-partial11.html.haml",
            "#{view_base_folder}/subfolder/_my-partial12.html.haml"
          ])
        end
      end

      context 'when the file does not include a partial' do
        let(:file_content) do
          <<~FILE
            Beginning of file
            End of file
          FILE
        end

        it 'returns an empty array' do
          expect(subject).to match_array([])
        end
      end
    end
  end

  describe '#find_pattern_in_file' do
    let(:subject) { described_class.new.find_pattern_in_file(file.path, /pattern/) }
    let(:file)    { Tempfile.new('find_pattern_in_file') }

    before do
      file.write(file_content)
      file.close
    end

    context 'when the file contains the pattern' do
      let(:file_content) do
        <<~FILE
          Beginning of file

          pattern
          pattern
          pattern

          End of file
        FILE
      end

      it 'returns the pattern once' do
        expect(subject).to match_array(%w[pattern])
      end
    end

    context 'when the file does not contain the pattern' do
      let(:file_content) do
        <<~FILE
          Beginning of file
          End of file
        FILE
      end

      it 'returns an empty array' do
        expect(subject).to match_array([])
      end
    end
  end
end
