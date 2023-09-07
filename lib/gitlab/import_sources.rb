# frozen_string_literal: true

# Gitlab::ImportSources module
#
# Define import sources that can be used
# during the creation of new project
#
module Gitlab
  module ImportSources
    ImportSource = Struct.new(:name, :title, :importer)

    IMPORT_TABLE = [
      ImportSource.new('github',           'GitHub',            Gitlab::GithubImport::ParallelImporter),
      ImportSource.new('bitbucket',        'Bitbucket Cloud',   Gitlab::BitbucketImport::Importer),
      ImportSource.new('bitbucket_server', 'Bitbucket Server',  Gitlab::BitbucketServerImport::Importer),
      ImportSource.new('fogbugz',          'FogBugz',           Gitlab::FogbugzImport::Importer),
      ImportSource.new('git',              'Repository by URL', nil),
      ImportSource.new('gitlab_project',   'GitLab export',     Gitlab::ImportExport::Importer),
      ImportSource.new('gitea',            'Gitea',             Gitlab::LegacyGithubImport::Importer),
      ImportSource.new('manifest',         'Manifest file',     nil)
    ].freeze

    class << self
      prepend_mod_with('Gitlab::ImportSources') # rubocop: disable Cop/InjectEnterpriseEditionModule

      def options
        import_table.to_h { |importer| [importer.title, importer.name] }
      end

      def values
        import_table.map(&:name)
      end

      def importer_names
        import_table.select(&:importer).map(&:name)
      end

      def importer(name)
        import_table.find { |import_source| import_source.name == name }.importer
      end

      def title(name)
        options.key(name)
      end

      def import_table
        bitbucket_parallel_enabled = Feature.enabled?(:bitbucket_parallel_importer)
        bitbucket_server_parallel_enabled = Feature.enabled?(:bitbucket_server_parallel_importer)

        return IMPORT_TABLE unless bitbucket_parallel_enabled || bitbucket_server_parallel_enabled

        import_table = IMPORT_TABLE.deep_dup

        import_table[1].importer = Gitlab::BitbucketImport::ParallelImporter if bitbucket_parallel_enabled
        import_table[2].importer = Gitlab::BitbucketServerImport::ParallelImporter if bitbucket_server_parallel_enabled

        import_table
      end
    end
  end
end
