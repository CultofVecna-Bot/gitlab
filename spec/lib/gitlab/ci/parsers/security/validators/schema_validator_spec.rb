# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Parsers::Security::Validators::SchemaValidator, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  let(:supported_dast_versions) { described_class::SUPPORTED_VERSIONS[:dast].join(', ') }

  let(:scanner) do
    {
      'id' => 'my-dast-scanner',
      'name' => 'My DAST scanner',
      'version' => '0.2.0',
      'vendor' => { 'name' => 'A DAST scanner' }
    }
  end

  let(:report_type) { :dast }

  let(:valid_data) do
    {
      'scan' => {
        'analyzer' => {
          'id' => 'my-dast-analyzer',
          'name' => 'My DAST analyzer',
          'version' => '0.1.0',
          'vendor' => { 'name' => 'A DAST analyzer' }
        },
        'end_time' => '2020-01-28T03:26:02',
        'scanned_resources' => [],
        'scanner' => scanner,
        'start_time' => '2020-01-28T03:26:01',
        'status' => 'success',
        'type' => report_type.to_s
      },
      'version' => report_version,
      'vulnerabilities' => []
    }
  end

  let(:report_data) { valid_data }

  let(:validator) { described_class.new(report_type, report_data, report_version, project: project, scanner: scanner) }

  shared_examples 'report is valid' do
    context 'and the report is valid' do
      it { is_expected.to be_truthy }
    end
  end

  shared_examples 'logs related information' do
    it 'logs related information' do
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: "security report schema validation problem",
        security_report_type: report_type,
        security_report_version: report_version,
        project_id: project.id,
        security_report_failure: security_report_failure,
        security_report_scanner_id: scanner['id'],
        security_report_scanner_version: scanner['version']
      )

      subject
    end
  end

  shared_examples 'report is invalid' do
    context 'and the report is invalid' do
      let(:report_data) do
        {
          'version' => report_version
        }
      end

      let(:security_report_failure) { 'schema_validation_fails' }

      it { is_expected.to be_falsey }

      it_behaves_like 'logs related information'
    end
  end

  describe 'SUPPORTED_VERSIONS' do
    schema_path = Rails.root.join("lib", "gitlab", "ci", "parsers", "security", "validators", "schemas")

    it 'matches DEPRECATED_VERSIONS keys' do
      expect(described_class::SUPPORTED_VERSIONS.keys).to eq(described_class::DEPRECATED_VERSIONS.keys)
    end

    context 'when all files under schema path are explicitly listed' do
      # We only care about the part that comes before report-format.json
      # https://rubular.com/r/N8Juz7r8hYDYgD
      filename_regex = /(?<report_type>[-\w]*)-report-format.json/

      versions = Dir.glob(File.join(schema_path, "*", File::SEPARATOR)).map { |path| path.split("/").last }

      versions.each do |version|
        files = Dir[schema_path.join(version, "*.json")]

        files.each do |file|
          matches = filename_regex.match(file)
          report_type = matches[:report_type].tr("-", "_").to_sym

          it "#{report_type} #{version}" do
            expect(described_class::SUPPORTED_VERSIONS[report_type]).to include(version)
          end
        end
      end
    end

    context 'when every SUPPORTED_VERSION has a corresponding JSON file' do
      described_class::SUPPORTED_VERSIONS.each_key do |report_type|
        # api_fuzzing is covered by DAST schema
        next if report_type == :api_fuzzing

        described_class::SUPPORTED_VERSIONS[report_type].each do |version|
          it "#{report_type} #{version} schema file is present" do
            filename = "#{report_type.to_s.tr("_", "-")}-report-format.json"
            full_path = schema_path.join(version, filename)
            expect(File.file?(full_path)).to be true
          end
        end
      end
    end
  end

  describe '#valid?' do
    subject { validator.valid? }

    context 'when given a supported MAJOR.MINOR schema version' do
      let(:report_version) do
        latest_vendored_version = described_class::SUPPORTED_VERSIONS[report_type].last.split(".")
        (latest_vendored_version[0...2] << "34").join(".")
      end

      it_behaves_like 'report is valid'
      it_behaves_like 'report is invalid'
    end

    context 'when given a supported schema version' do
      let(:report_version) { described_class::SUPPORTED_VERSIONS[report_type].last }

      it_behaves_like 'report is valid'
      it_behaves_like 'report is invalid'
    end

    context 'when given a deprecated schema version' do
      let(:deprecations_hash) do
        {
          dast: %w[10.0.0]
        }
      end

      let(:report_version) { described_class::DEPRECATED_VERSIONS[report_type].last }

      before do
        stub_const("#{described_class}::DEPRECATED_VERSIONS", deprecations_hash)
      end

      context 'and the report passes schema validation' do
        let(:security_report_failure) { 'using_deprecated_schema_version' }

        it { is_expected.to be_truthy }

        it_behaves_like 'logs related information'
      end

      context 'and the report does not pass schema validation' do
        let(:report_data) do
          valid_data.delete('vulnerabilities')
          valid_data
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when given an unsupported schema version' do
      let(:report_version) { "12.37.0" }

      context 'and the report is valid' do
        let(:security_report_failure) { 'using_unsupported_schema_version' }

        it { is_expected.to be_falsey }

        it_behaves_like 'logs related information'
      end

      context 'and the report is invalid' do
        let(:report_data) do
          {
            'version' => report_version
          }
        end

        context 'and scanner information is empty' do
          let(:scanner) { {} }

          it 'logs related information' do
            expect(Gitlab::AppLogger).to receive(:info).with(
              message: "security report schema validation problem",
              security_report_type: report_type,
              security_report_version: report_version,
              project_id: project.id,
              security_report_failure: 'schema_validation_fails',
              security_report_scanner_id: nil,
              security_report_scanner_version: nil
            )

            expect(Gitlab::AppLogger).to receive(:info).with(
              message: "security report schema validation problem",
              security_report_type: report_type,
              security_report_version: report_version,
              project_id: project.id,
              security_report_failure: 'using_unsupported_schema_version',
              security_report_scanner_id: nil,
              security_report_scanner_version: nil
            )

            subject
          end
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when not given a schema version' do
      let(:report_version) { nil }

      let(:report_data) do
        {
          'vulnerabilities' => []
        }
      end

      it { is_expected.to be_falsey }
    end
  end

  shared_examples 'report is valid with no error' do
    context 'and the report is valid' do
      it { is_expected.to be_empty }
    end
  end

  shared_examples 'report with expected errors' do
    it { is_expected.to match_array(expected_errors) }
  end

  describe '#errors' do
    subject { validator.errors }

    context 'when given a supported schema version' do
      let(:report_version) { described_class::SUPPORTED_VERSIONS[report_type].last }

      it_behaves_like 'report is valid with no error'

      context 'and the report is invalid' do
        let(:report_data) do
          valid_data.delete('vulnerabilities')
          valid_data
        end

        let(:expected_errors) do
          [
            'root is missing required keys: vulnerabilities'
          ]
        end

        it_behaves_like 'report with expected errors'
      end
    end

    context 'when given a deprecated schema version' do
      let(:deprecations_hash) do
        {
          dast: %w[10.0.0]
        }
      end

      let(:report_version) { described_class::DEPRECATED_VERSIONS[report_type].last }

      before do
        stub_const("#{described_class}::DEPRECATED_VERSIONS", deprecations_hash)
      end

      it_behaves_like 'report is valid with no error'

      context 'and the report does not pass schema validation' do
        let(:report_data) do
          valid_data['version'] = "V2.7.0"
          valid_data.delete('vulnerabilities')
          valid_data
        end

        let(:expected_errors) do
          [
            "property '/version' does not match pattern: ^[0-9]+\\.[0-9]+\\.[0-9]+$",
            "root is missing required keys: vulnerabilities"
          ]
        end

        it_behaves_like 'report with expected errors'
      end
    end

    context 'when given an unsupported schema version' do
      let(:report_version) { "12.37.0" }
      let(:expected_unsupported_message) do
        "Version #{report_version} for report type #{report_type} is unsupported, supported versions for this report type are: "\
        "#{supported_dast_versions}. GitLab will attempt to validate this report against the earliest supported "\
        "versions of this report type, to show all the errors but will not ingest the report"
      end

      context 'and the report is valid' do
        let(:expected_errors) do
          [
            expected_unsupported_message
          ]
        end

        it_behaves_like 'report with expected errors'
      end

      context 'and the report is invalid' do
        let(:report_data) do
          valid_data.delete('vulnerabilities')
          valid_data
        end

        let(:expected_errors) do
          [
            expected_unsupported_message,
            "root is missing required keys: vulnerabilities"
          ]
        end

        it_behaves_like 'report with expected errors'
      end
    end

    context 'when not given a schema version' do
      let(:report_version) { nil }
      let(:expected_missing_version_message) do
        "Report version not provided, #{report_type} report type supports versions: #{supported_dast_versions}. GitLab "\
        "will attempt to validate this report against the earliest supported versions of this report type, to show all "\
        "the errors but will not ingest the report"
      end

      let(:report_data) do
        valid_data.delete('version')
        valid_data
      end

      let(:expected_errors) do
        [
          "root is missing required keys: version",
          expected_missing_version_message
        ]
      end

      it_behaves_like 'report with expected errors'
    end
  end

  shared_examples 'report is valid with no warning' do
    context 'and the report is valid' do
      it { is_expected.to be_empty }
    end
  end

  shared_examples 'report with expected warnings' do
    it { is_expected.to match_array(expected_deprecation_warnings) }
  end

  describe '#deprecation_warnings' do
    subject { validator.deprecation_warnings }

    context 'when given a supported schema version' do
      let(:report_version) { described_class::SUPPORTED_VERSIONS[report_type].last }

      context 'and the report is valid' do
        it { is_expected.to be_empty }
      end

      context 'and the report is invalid' do
        let(:report_data) do
          valid_data.delete('vulnerabilities')
          valid_data
        end

        it { is_expected.to be_empty }
      end
    end

    context 'when given a deprecated schema version' do
      let(:deprecations_hash) do
        {
          dast: %w[V2.7.0]
        }
      end

      let(:report_version) { described_class::DEPRECATED_VERSIONS[report_type].last }
      let(:current_dast_versions) { described_class::CURRENT_VERSIONS[:dast].join(', ') }
      let(:expected_deprecation_message) do
        "version #{report_version} for report type #{report_type} is deprecated. "\
        "However, GitLab will still attempt to parse and ingest this report. "\
        "Upgrade the security report to one of the following versions: #{current_dast_versions}."
      end

      let(:expected_deprecation_warnings) do
        [
          expected_deprecation_message
        ]
      end

      before do
        stub_const("#{described_class}::DEPRECATED_VERSIONS", deprecations_hash)
      end

      context 'and the report passes schema validation' do
        it_behaves_like 'report with expected warnings'
      end

      context 'and the report does not pass schema validation' do
        let(:report_data) do
          valid_data['version'] = "V2.7.0"
          valid_data.delete('vulnerabilities')
          valid_data
        end

        it_behaves_like 'report with expected warnings'
      end
    end

    context 'when given an unsupported schema version' do
      let(:report_version) { "21.37.0" }
      let(:expected_deprecation_warnings) { [] }

      it_behaves_like 'report with expected warnings'
    end
  end

  describe '#warnings' do
    subject { validator.warnings }

    context 'when given a supported MAJOR.MINOR schema version' do
      let(:report_version) do
        latest_vendored_version = described_class::SUPPORTED_VERSIONS[report_type].last.split(".")
        (latest_vendored_version[0...2] << "34").join(".")
      end

      let(:latest_patch_version) do
        ::Security::ReportSchemaVersionMatcher.new(
          report_declared_version: report_version,
          supported_versions: described_class::SUPPORTED_VERSIONS[report_type]
        ).call
      end

      let(:message) do
        "This report uses a supported MAJOR.MINOR schema version but the PATCH version doesn't match"\
        " any vendored schema version. Validation will be attempted against version"\
        " #{latest_patch_version}"
      end

      context 'and the report is valid' do
        it { is_expected.to match_array([message]) }

        context 'without license', unless: Gitlab.ee? do
          let(:schema_path) { Rails.root.join(*%w[lib gitlab ci parsers security validators schemas]) }

          it 'tries to validate against the latest patch version available' do
            expect(File).to receive(:file?).with("#{schema_path}/#{report_version}/#{report_type}-report-format.json")
            expect(File).to receive(:file?).with("#{schema_path}/#{latest_patch_version}/#{report_type}-report-format.json")

            subject
          end
        end

        context 'with license', if: Gitlab.ee? do
          let(:schema_path) { Rails.root.join(*%w[ee lib ee gitlab ci parsers security validators schemas]) }

          it 'tries to validate against the latest patch version available' do
            expect(File).to receive(:file?).with("#{schema_path}/#{report_version}/#{report_type}-report-format.json")
            expect(File).to receive(:file?).with("#{schema_path}/#{latest_patch_version}/#{report_type}-report-format.json")

            subject
          end
        end
      end

      context 'and the report is invalid' do
        let(:report_data) do
          {
            'version' => report_version
          }
        end

        let(:security_report_failure) { 'schema_validation_fails' }

        it { is_expected.to match_array([message]) }

        it_behaves_like 'logs related information'
      end
    end

    context 'when given a supported schema version' do
      let(:report_version) { described_class::SUPPORTED_VERSIONS[report_type].last }

      it_behaves_like 'report is valid with no warning'

      context 'and the report is invalid' do
        let(:report_data) do
          {
            'version' => report_version
          }
        end

        it { is_expected.to be_empty }
      end
    end

    context 'when given a deprecated schema version' do
      let(:deprecated_version) { '14.1.3' }
      let(:report_version) { deprecated_version }
      let(:deprecations_hash) do
        {
          dast: %w[deprecated_version]
        }
      end

      before do
        stub_const("#{described_class}::DEPRECATED_VERSIONS", deprecations_hash)
      end

      context 'and the report passes schema validation' do
        it { is_expected.to be_empty }
      end

      context 'and the report does not pass schema validation' do
        let(:report_data) do
          valid_data.delete('vulnerabilities')
          valid_data
        end

        it { is_expected.to be_empty }
      end
    end

    context 'when given an unsupported schema version' do
      let(:report_version) { "12.37.0" }

      it_behaves_like 'report is valid with no warning'

      context 'and the report is invalid' do
        let(:report_data) do
          {
            'version' => report_version
          }
        end

        it { is_expected.to be_empty }
      end
    end

    context 'when not given a schema version' do
      let(:report_version) { nil }

      it { is_expected.to be_empty }
    end
  end
end
