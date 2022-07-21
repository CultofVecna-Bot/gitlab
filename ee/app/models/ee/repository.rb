# frozen_string_literal: true

module EE
  # Repository EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `Repository` model
  module Repository
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    MIRROR_REMOTE = "upstream"

    prepended do
      include Elastic::RepositoriesSearch

      delegate :checksum, :find_remote_root_ref, to: :raw_repository
    end

    # Runs code after a repository has been synced.
    def after_sync
      expire_all_method_caches
      expire_branch_cache if exists?
      expire_content_cache
    end

    def fetch_upstream(url, forced: false, check_tags_changed: false)
      fetch_remote(
        url,
        refmap: ["+refs/heads/*:refs/remotes/#{MIRROR_REMOTE}/*"],
        ssh_auth: project&.import_data,
        forced: forced,
        check_tags_changed: check_tags_changed
      )
    end

    def upstream_branches
      @upstream_branches ||= remote_branches(MIRROR_REMOTE)
    end

    def diverged_from_upstream?(branch_name)
      diverged?(branch_name, MIRROR_REMOTE) do |branch_commit, upstream_commit|
        !raw_repository.ancestor?(branch_commit.id, upstream_commit.id)
      end
    end

    def upstream_has_diverged?(branch_name, remote_ref)
      diverged?(branch_name, remote_ref) do |branch_commit, upstream_commit|
        !raw_repository.ancestor?(upstream_commit.id, branch_commit.id)
      end
    end

    def up_to_date_with_upstream?(branch_name)
      diverged?(branch_name, MIRROR_REMOTE) do |branch_commit, upstream_commit|
        ancestor?(branch_commit.id, upstream_commit.id)
      end
    end

    override :keep_around
    def keep_around(*shas)
      super
    ensure
      # If there are no SHAs received then there is no write_ref executed.
      # The following condition avoids to publish unnecessary events.
      if shas.compact.any?
        # The keep_around method is called from different places. One of them
        # is when a pipeline is created. So, in this case, it is still under
        # Ci::Pipeline.transaction. It's safe to skip the transaction check
        # because we already wrote the refs to the repository on disk.
        Sidekiq::Worker.skipping_transaction_check do
          ::Gitlab::EventStore.publish(
            ::Repositories::KeepAroundRefsCreatedEvent.new(data: { project_id: project.id })
          )
        end
      end
    end

    override :after_change_head
    def after_change_head
      super
    ensure
      log_geo_updated_event
    end

    def log_geo_updated_event
      return unless ::Gitlab::Geo.primary?

      ::Geo::RepositoryUpdatedService.new(self).execute
    end

    def code_owners_blob(ref:)
      possible_code_owner_blobs = ::Gitlab::CodeOwners::FILE_PATHS.map { |path| [ref, path] }
      blobs_at(possible_code_owner_blobs).compact.first
    end

    def insights_config_for(sha)
      blob_data_at(sha, ::Gitlab::Insights::CONFIG_FILE_PATH)
    end

    # Update the default branch querying the remote to determine its HEAD
    def update_root_ref(remote_url, authorization)
      root_ref = find_remote_root_ref(remote_url, authorization)
      change_head(root_ref) if root_ref.present?
    rescue ::Gitlab::Git::Repository::NoRepository => e
      ::Gitlab::AppLogger.error("Error updating root ref for repository #{full_path} (#{container.id}): #{e.message}.")
      nil
    end

    private

    def diverged?(branch_name, remote_ref)
      branch_commit = commit("refs/heads/#{branch_name}")
      upstream_commit = commit("refs/remotes/#{remote_ref}/#{branch_name}")

      if branch_commit && upstream_commit
        yield branch_commit, upstream_commit
      else
        false
      end
    end
  end
end
