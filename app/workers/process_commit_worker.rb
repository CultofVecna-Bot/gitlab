# frozen_string_literal: true

# Worker for processing individual commit messages pushed to a repository.
#
# Jobs for this worker are scheduled for every commit that contains mentionable
# references in its message and does not exist in the upstream project. As a
# result of this the workload of this worker should be kept to a bare minimum.
# Consider using an extra worker if you need to add any extra (and potentially
# slow) processing of commits.
class ProcessCommitWorker
  include ApplicationWorker

  data_consistency :always

  sidekiq_options retry: 3

  feature_category :source_code_management
  urgency :high
  weight 3
  idempotent!
  loggable_arguments 2, 3

  # project_id - The ID of the project this commit belongs to.
  # user_id - The ID of the user that pushed the commit.
  # commit_hash - Hash containing commit details to use for constructing a
  #               Commit object without having to use the Git repository.
  # default - The data was pushed to the default branch.
  def perform(project_id, user_id, commit_hash, default = false)
    project = Project.id_in(project_id).first

    return unless project

    user = User.id_in(user_id).first

    return unless user

    commit = Commit.build_from_sidekiq_hash(project, commit_hash)
    author = commit.author || user

    process_commit_message(project, commit, user, author, default)
    update_issue_metrics(commit, author)
  end

  def process_commit_message(project, commit, user, author, default = false)
    # Ignore closing references from GitLab-generated commit messages.
    find_closing_issues = default && !commit.merged_merge_request?(user)
    closed_issues = find_closing_issues ? issues_to_close(project, commit, user) : []

    close_issues(project, user, author, commit, closed_issues) if closed_issues.any?
    commit.create_cross_references!(author, closed_issues)
  end

  def close_issues(project, user, author, commit, issues)
    if Feature.enabled?(:process_issue_closure_in_background, project)
      Issues::CloseWorker.bulk_perform_async_with_contexts(
        issues,
        arguments_proc: -> (issue) {
          [project.id, issue.id, issue.class.to_s, { closed_by: author.id, commit_hash: commit.to_hash }]
        },
        context_proc: -> (issue) { { project: project } }
      )
    else
      # We don't want to run permission related queries for every single issue,
      # therefore we use IssueCollection here and skip the authorization check in
      # Issues::CloseService#execute.
      IssueCollection.new(issues).updatable_by_user(user).each do |issue|
        Issues::CloseService.new(project: project, current_user: author)
          .close_issue(issue, closed_via: commit)
      end
    end
  end

  def issues_to_close(project, commit, user)
    Gitlab::ClosingIssueExtractor
      .new(project, user)
      .closed_by_message(commit.safe_message)
  end

  def update_issue_metrics(commit, author)
    mentioned_issues = commit.all_references(author).issues

    return if mentioned_issues.empty?

    Issue::Metrics.for_issues(mentioned_issues)
      .with_first_mention_not_earlier_than(commit.committed_date)
      .update_all(first_mentioned_in_commit_at: commit.committed_date)
  end
end
