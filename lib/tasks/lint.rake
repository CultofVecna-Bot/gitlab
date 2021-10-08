# frozen_string_literal: true

unless Rails.env.production?
  namespace :lint do
    task :static_verification_env do
      ENV['STATIC_VERIFICATION'] = 'true'
    end

    desc "GitLab | Lint | Static verification"
    task static_verification: %w[
      lint:static_verification_env
      dev:load
    ] do
      Gitlab::Utils::Override.verify!
      Gitlab::Utils::DelegatorOverride.verify!
    end

    desc "GitLab | Lint | Lint JavaScript files using ESLint"
    task :javascript do
      Rake::Task['eslint'].invoke
    end

    desc "GitLab | Lint | Lint HAML files"
    task :haml do
      Rake::Task['haml_lint'].invoke
    rescue RuntimeError # The haml_lint tasks raise a RuntimeError
      exit(1)
    end

    desc "GitLab | Lint | Run several lint checks"
    task :all do
      status = 0

      tasks = %w[
        config_lint
        lint:haml
        gettext:lint
        lint:static_verification
        gitlab:sidekiq:all_queues_yml:check
      ]

      if Gitlab.ee?
        # These tasks will fail on FOSS installations
        # (e.g. gitlab-org/gitlab-foss) since they test against a single
        # file that is generated by an EE installation, which can
        # contain values that a FOSS installation won't find.  To work
        # around this we will only enable this task on EE installations.
        tasks << 'gettext:updated_check'
        tasks << 'gitlab:sidekiq:sidekiq_queues_yml:check'
      end

      tasks.each do |task|
        pid = Process.fork do
          puts "*** Running rake task: #{task} ***"

          Rake::Task[task].invoke
        rescue SystemExit => ex
          warn "!!! Rake task #{task} exited:"
          raise ex
        rescue StandardError, ScriptError => ex
          warn "!!! Rake task #{task} raised #{ex.class}:"
          raise ex
        end

        Process.waitpid(pid)
        status += $?.exitstatus
      end

      exit(status)
    end
  end
end
