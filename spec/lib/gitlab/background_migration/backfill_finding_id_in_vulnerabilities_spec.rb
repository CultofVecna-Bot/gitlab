# frozen_string_literal: true

require 'spec_helper'
RSpec.describe Gitlab::BackgroundMigration::BackfillFindingIdInVulnerabilities, schema: 20230912105945, feature_category: :vulnerability_management do # rubocop:disable Layout/LineLength
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:users) { table(:users) }
  let(:members) { table(:members) }
  let(:vulnerability_identifiers) { table(:vulnerability_identifiers) }
  let(:vulnerability_scanners) { table(:vulnerability_scanners) }
  let(:vulnerability_findings) { table(:vulnerability_occurrences) }
  let(:vulnerabilities) { table(:vulnerabilities) }
  let!(:user) { create_user(email: "test1@example.com", username: "test1") }
  let!(:namespace) { namespaces.create!(name: "test-1", path: "test-1", owner_id: user.id) }
  let!(:project) do
    projects.create!(
      id: 9999, namespace_id: namespace.id,
      project_namespace_id: namespace.id,
      creator_id: user.id
    )
  end

  let!(:membership) do
    members.create!(access_level: 50, source_id: project.id, source_type: "Project", user_id: user.id, state: 0,
      notification_level: 3, type: "ProjectMember", member_namespace_id: namespace.id)
  end

  let(:migration_attrs) do
    {
      start_id: vulnerabilities.first.id,
      end_id: vulnerabilities.last.id,
      batch_table: :vulnerabilities,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  describe "#perform" do
    subject(:background_migration) { described_class.new(**migration_attrs).perform }

    # This scenario is what usually happens because we first create a Vulnerabilities::Finding record, then create
    # a Vulnerability record and populate the Vulnerabilities::Finding#vulnerability_id
    let(:vulnerabilities_finding_1) { create_finding(project, vulnerability_id: vulnerability_without_finding_id.id) }
    let(:vulnerability_without_finding_id) { create_vulnerability }

    # This scenario can occur because we have modified our Vulnerabilities ingestion pipeline to populate
    # vulnerabilities.finding_id as soon as possible
    let(:vulnerabilities_finding_2) { create_finding(project) }
    let(:vulnerability_with_finding_id) { create_vulnerability(finding_id: vulnerabilities_finding_2.id) }

    it 'backfills finding_id column in the vulnerabilities table' do
      expect { background_migration }.to change { vulnerability_without_finding_id.reload.finding_id }
        .from(nil).to(vulnerabilities_finding_1.id)
    end

    it 'does not affect rows with finding_id populated' do
      expect { background_migration }.not_to change { vulnerability_with_finding_id.reload.finding_id }
    end
  end

  private

  def create_scanner(project, overrides = {})
    attrs = {
      project_id: project.id,
      external_id: "test_vulnerability_scanner",
      name: "Test Vulnerabilities::Scanner"
    }.merge(overrides)

    vulnerability_scanners.create!(attrs)
  end

  def create_identifier(project, overrides = {})
    attrs = {
      project_id: project.id,
      external_id: "CVE-2018-1234",
      external_type: "CVE",
      name: "CVE-2018-1234",
      fingerprint: SecureRandom.hex(20)
    }.merge(overrides)

    vulnerability_identifiers.create!(attrs)
  end

  def create_finding(project, overrides = {})
    attrs = {
      project_id: project.id,
      scanner_id: create_scanner(project).id,
      severity: 5, # medium
      confidence: 2, # unknown,
      report_type: 99, # generic
      primary_identifier_id: create_identifier(project).id,
      project_fingerprint: SecureRandom.hex(20),
      location_fingerprint: SecureRandom.hex(20),
      uuid: SecureRandom.uuid,
      name: "CVE-2018-1234",
      raw_metadata: "{}",
      metadata_version: "test:1.0"
    }.merge(overrides)

    vulnerability_findings.create!(attrs)
  end

  def create_vulnerability(overrides = {})
    attrs = {
      project_id: project.id,
      author_id: user.id,
      title: 'test',
      severity: 1,
      confidence: 1,
      report_type: 1,
      state: 1,
      detected_at: Time.zone.now
    }.merge(overrides)

    vulnerabilities.create!(attrs)
  end

  def create_user(overrides = {})
    attrs = {
      email: "test@example.com",
      notification_email: "test@example.com",
      name: "test",
      username: "test",
      state: "active",
      projects_limit: 10
    }.merge(overrides)

    users.create!(attrs)
  end
end
