# frozen_string_literal: true

require 'spec_helper'

require_migration!

RSpec.describe CleanupProjectsWithNullHasExternalWiki, :migration, schema: 20210105025900 do
  let(:namespace) { table(:namespaces).create!(name: 'foo', path: 'bar') }
  let(:projects) { table(:projects) }
  let(:services) { table(:services) }
  let(:constraint_name) { 'check_421d399b70' }

  def create_projects!(num)
    Array.new(num) do
      projects.create!(namespace_id: namespace.id)
    end
  end

  def create_active_external_wiki_integrations!(*projects)
    projects.each do |project|
      services.create!(type: 'ExternalWikiService', project_id: project.id, active: true)
    end
  end

  def create_disabled_external_wiki_integrations!(*projects)
    projects.each do |project|
      services.create!(type: 'ExternalWikiService', project_id: project.id, active: false)
    end
  end

  def create_active_other_integrations!(*projects)
    projects.each do |project|
      services.create!(type: 'NotAnExternalWikiService', project_id: project.id, active: true)
    end
  end

  it 'sets `projects.has_external_wiki` correctly' do
    allow(ActiveRecord::Base.connection).to receive(:transaction_open?).and_return(false)

    project_with_external_wiki_1,
      project_with_external_wiki_2,
      project_with_external_wiki_3,
      project_with_disabled_external_wiki_1,
      project_with_disabled_external_wiki_2,
      project_with_disabled_external_wiki_3,
      project_without_external_wiki_1,
      project_without_external_wiki_2,
      project_without_external_wiki_3 = create_projects!(9)

    create_active_external_wiki_integrations!(
      project_with_external_wiki_1,
      project_with_external_wiki_2,
      project_with_external_wiki_3
    )

    create_disabled_external_wiki_integrations!(
      project_with_disabled_external_wiki_1,
      project_with_disabled_external_wiki_2,
      project_with_disabled_external_wiki_3
    )

    create_active_other_integrations!(
      project_without_external_wiki_1,
      project_without_external_wiki_2,
      project_without_external_wiki_3
    )

    # PG triggers on the services table added in a previous migration
    # will have set the `has_external_wiki` columns to correct data when
    # the services records were created above.
    #
    # We set the `has_external_wiki` columns for projects to NULL or incorrect
    # data manually below to emulate projects in a state before the PG
    # triggers were added.
    project_with_external_wiki_1.update!(has_external_wiki: nil)
    project_with_external_wiki_2.update!(has_external_wiki: false)

    project_with_disabled_external_wiki_1.update!(has_external_wiki: nil)
    project_with_disabled_external_wiki_2.update!(has_external_wiki: true)

    project_without_external_wiki_1.update!(has_external_wiki: nil)
    project_without_external_wiki_2.update!(has_external_wiki: true)

    migrate!

    expected_true = [
      project_with_external_wiki_1,
      project_with_external_wiki_2,
      project_with_external_wiki_3
    ].each(&:reload).map(&:has_external_wiki)

    expected_false = [
      project_without_external_wiki_1,
      project_without_external_wiki_2,
      project_without_external_wiki_3,
      project_with_disabled_external_wiki_1,
      project_with_disabled_external_wiki_2,
      project_with_disabled_external_wiki_3
    ].each(&:reload).map(&:has_external_wiki)

    expect(expected_true).to all(eq(true))
    expect(expected_false).to all(eq(false))
  end
end
