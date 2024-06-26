# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Backup::Database, :reestablished_active_record_base, feature_category: :backup_restore do
  let(:progress) { StringIO.new }
  let(:progress_output) { progress.string }
  let(:backup_id) { 'some_id' }
  let(:one_database_configured?) { base_models_for_backup.one? }
  let(:timeout_service) do
    instance_double(Gitlab::Database::TransactionTimeoutSettings, restore_timeouts: nil, disable_timeouts: nil)
  end

  let(:base_models_for_backup) do
    Gitlab::Database.database_base_models_with_gitlab_shared.select do |database_name|
      Gitlab::Database.has_database?(database_name)
    end
  end

  before(:all) do # rubocop:disable RSpec/BeforeAll
    Rake.application.rake_require 'active_record/railties/databases'
    Rake.application.rake_require 'tasks/gitlab/backup'
    Rake.application.rake_require 'tasks/gitlab/shell'
    Rake.application.rake_require 'tasks/gitlab/db'
    Rake.application.rake_require 'tasks/cache'
  end

  describe '#dump', :delete do
    let(:force) { true }

    subject { described_class.new(progress, force: force) }

    it 'creates gzipped database dumps' do
      Dir.mktmpdir do |dir|
        subject.dump(dir, backup_id)

        base_models_for_backup.each_key do |database_name|
          filename = database_name == 'main' ? 'database.sql.gz' : "#{database_name}_database.sql.gz"
          expect(File.exist?(File.join(dir, filename))).to eq(true)
        end
      end
    end

    context 'when using multiple databases' do
      before do
        skip_if_shared_database(:ci)
      end

      it 'uses snapshots' do
        Dir.mktmpdir do |dir|
          expect_next_instances_of(Backup::DatabaseModel, 2) do |adapter|
            expect(adapter.connection).to receive(:begin_transaction).with(
              isolation: :repeatable_read
            ).and_call_original
            expect(adapter.connection).to receive(:select_value).with(
              "SELECT pg_export_snapshot()"
            ).and_call_original
            expect(adapter.connection).to receive(:rollback_transaction).and_call_original
          end

          subject.dump(dir, backup_id)
        end
      end

      it 'disables transaction time out' do
        number_of_databases = base_models_for_backup.count
        expect(Gitlab::Database::TransactionTimeoutSettings)
          .to receive(:new).exactly(2 * number_of_databases).times.and_return(timeout_service)
        expect(timeout_service).to receive(:disable_timeouts).exactly(number_of_databases).times
        expect(timeout_service).to receive(:restore_timeouts).exactly(number_of_databases).times

        Dir.mktmpdir do |dir|
          subject.dump(dir, backup_id)
        end
      end
    end

    context 'when using a single databases' do
      before do
        skip_if_database_exists(:ci)
      end

      it 'does not use snapshots' do
        Dir.mktmpdir do |dir|
          base_model = Backup::DatabaseModel.new('main')
          expect(base_model.connection).not_to receive(:begin_transaction).with(
            isolation: :repeatable_read
          ).and_call_original
          expect(base_model.connection).not_to receive(:select_value).with(
            "SELECT pg_export_snapshot()"
          ).and_call_original
          expect(base_model.connection).not_to receive(:rollback_transaction).and_call_original

          subject.dump(dir, backup_id)
        end
      end
    end

    describe 'pg_dump arguments' do
      let(:snapshot_id) { 'fake_id' }
      let(:default_pg_args) do
        args = [
          '--clean',
          '--if-exists'
        ]

        if Gitlab::Database.database_mode == Gitlab::Database::MODE_MULTIPLE_DATABASES
          args + ["--snapshot=#{snapshot_id}"]
        else
          args
        end
      end

      let(:dumper) { double }
      let(:destination_dir) { 'tmp' }

      before do
        allow(Backup::Dump::Postgres).to receive(:new).and_return(dumper)
        allow(dumper).to receive(:dump).with(any_args).and_return(true)
      end

      shared_examples 'pg_dump arguments' do
        it 'calls Backup::Dump::Postgres with correct pg_dump arguments' do
          number_of_databases = base_models_for_backup.count
          if number_of_databases > 1
            expect_next_instances_of(Backup::DatabaseModel, number_of_databases) do |model|
              expect(model.connection).to receive(:select_value).with(
                "SELECT pg_export_snapshot()"
              ).and_return(snapshot_id)
            end
          end

          expect(dumper).to receive(:dump).with(anything, anything, expected_pg_args)

          subject.dump(destination_dir, backup_id)
        end
      end

      context 'when no PostgreSQL schemas are specified' do
        let(:expected_pg_args) { default_pg_args }

        include_examples 'pg_dump arguments'
      end

      context 'when a PostgreSQL schema is used' do
        let(:schema) { 'gitlab' }
        let(:expected_pg_args) do
          default_pg_args + ['-n', schema] + Gitlab::Database::EXTRA_SCHEMAS.flat_map do |schema|
            ['-n', schema.to_s]
          end
        end

        before do
          allow(Gitlab.config.backup).to receive(:pg_schema).and_return(schema)
        end

        include_examples 'pg_dump arguments'
      end
    end

    context 'when a StandardError (or descendant) is raised' do
      before do
        allow(FileUtils).to receive(:mkdir_p).and_raise(StandardError)
      end

      it 'restores timeouts' do
        Dir.mktmpdir do |dir|
          number_of_databases = base_models_for_backup.count
          expect(Gitlab::Database::TransactionTimeoutSettings)
            .to receive(:new).exactly(number_of_databases).times.and_return(timeout_service)
          expect(timeout_service).to receive(:restore_timeouts).exactly(number_of_databases).times

          expect { subject.dump(dir, backup_id) }.to raise_error StandardError
        end
      end
    end

    context 'when using GITLAB_BACKUP_* environment variables' do
      before do
        stub_env('GITLAB_BACKUP_PGHOST', 'test.invalid.')
      end

      it 'will override database.yml configuration' do
        # Expect an error because we can't connect to test.invalid.
        expect do
          Dir.mktmpdir { |dir| subject.dump(dir, backup_id) }
        end.to raise_error(Backup::DatabaseBackupError)

        expect do
          ApplicationRecord.connection.select_value('select 1')
        end.not_to raise_error

        expect(ENV['PGHOST']).to be_nil
      end
    end
  end

  describe '#restore' do
    let(:cmd) { %W[#{Gem.ruby} -e $stdout.puts(1)] }
    let(:backup_dir) { Rails.root.join("spec/fixtures/") }
    let(:force) { true }
    let(:rake_task) { instance_double(Rake::Task, invoke: true) }

    subject { described_class.new(progress, force: force) }

    before do
      allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)

      allow(subject).to receive(:pg_restore_cmd).and_return(cmd)
    end

    context 'when not forced' do
      let(:force) { false }

      it 'warns the user and waits' do
        expect(subject).to receive(:sleep)

        if one_database_configured?
          expect(Rake::Task['gitlab:db:drop_tables']).to receive(:invoke)
        else
          expect(Rake::Task['gitlab:db:drop_tables:main']).to receive(:invoke)
        end

        subject.restore(backup_dir, backup_id)

        expect(progress_output).to include('Removing all tables. Press `Ctrl-C` within 5 seconds to abort')
      end

      it 'has a pre restore warning' do
        expect(subject.pre_restore_warning).not_to be_nil
      end
    end

    context 'with an empty .gz file' do
      it 'returns successfully' do
        if one_database_configured?
          expect(Rake::Task['gitlab:db:drop_tables']).to receive(:invoke)
        else
          expect(Rake::Task['gitlab:db:drop_tables:main']).to receive(:invoke)
        end

        subject.restore(backup_dir, backup_id)

        expect(progress_output).to include("Restoring PostgreSQL database")
        expect(progress_output).to include("[DONE]")
        expect(progress_output).not_to include("ERRORS")
      end

      context 'when DECOMPRESS_CMD is set to tee' do
        before do
          stub_env('DECOMPRESS_CMD', 'tee')
        end

        it 'outputs a message about DECOMPRESS_CMD' do
          expect do
            subject.restore(backup_dir, backup_id)
          end.to output(/Using custom DECOMPRESS_CMD 'tee'/).to_stdout
        end
      end
    end

    context 'with a corrupted .gz file' do
      before do
        allow(subject).to receive(:file_name).and_return("#{backup_dir}big-image.png")
      end

      it 'raises a backup error' do
        if one_database_configured?
          expect(Rake::Task['gitlab:db:drop_tables']).to receive(:invoke)
        else
          expect(Rake::Task['gitlab:db:drop_tables:main']).to receive(:invoke)
        end

        expect { subject.restore(backup_dir, backup_id) }.to raise_error(Backup::Error)
      end
    end

    context 'when the restore command prints errors' do
      let(:visible_error) { "This is a test error\n" }
      let(:noise) { "must be owner of extension pg_trgm\nWARNING:  no privileges could be revoked for public\n" }
      let(:cmd) { %W[#{Gem.ruby} -e $stderr.write("#{noise}#{visible_error}")] }

      it 'filters out noise from errors and has a post restore warning' do
        if one_database_configured?
          expect(Rake::Task['gitlab:db:drop_tables']).to receive(:invoke)
        else
          expect(Rake::Task['gitlab:db:drop_tables:main']).to receive(:invoke)
        end

        subject.restore(backup_dir, backup_id)

        expect(progress_output).to include("ERRORS")
        expect(progress_output).not_to include(noise)
        expect(progress_output).to include(visible_error)
        expect(subject.post_restore_warning).not_to be_nil
      end
    end

    context 'with PostgreSQL settings defined in the environment' do
      let(:config) { YAML.load_file(File.join(Rails.root, 'config', 'database.yml'))['test'] }

      before do
        stub_env(ENV.to_h.merge({
          'GITLAB_BACKUP_PGHOST' => 'test.example.com',
          'PGPASSWORD' => 'donotchange'
        }))
      end

      it 'overrides default config values' do
        if one_database_configured?
          expect(Rake::Task['gitlab:db:drop_tables']).to receive(:invoke)
        else
          expect(Rake::Task['gitlab:db:drop_tables:main']).to receive(:invoke)
        end

        expect(ENV).to receive(:merge!).with(hash_including { 'PGHOST' => 'test.example.com' })
        expect(ENV).not_to receive(:[]=).with('PGPASSWORD', anything)

        subject.restore(backup_dir, backup_id)

        expect(ENV['PGPORT']).to eq(config['port']) if config['port']
        expect(ENV['PGUSER']).to eq(config['username']) if config['username']
      end
    end

    context 'when the source file is missing' do
      context 'for main database' do
        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with("#{backup_dir}database.sql.gz").and_return(false)
          allow(File).to receive(:exist?).with("#{backup_dir}ci_database.sql.gz").and_return(false)
        end

        it 'raises an error about missing source file' do
          if one_database_configured?
            expect(Rake::Task['gitlab:db:drop_tables']).not_to receive(:invoke)
          else
            expect(Rake::Task['gitlab:db:drop_tables:main']).not_to receive(:invoke)
          end

          expect do
            subject.restore('db', backup_id)
          end.to raise_error(Backup::Error, /Source database file does not exist/)
        end
      end

      context 'for ci database' do
        it 'ci database tolerates missing source file' do
          expect { subject.restore(backup_dir, backup_id) }.not_to raise_error
        end
      end
    end
  end
end
