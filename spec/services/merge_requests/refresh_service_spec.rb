require 'spec_helper'

describe MergeRequests::RefreshService do
  include ProjectForksHelper

  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:service) { described_class }

  describe '#execute' do
    before do
      @user = create(:user)
      group = create(:group)
      group.add_owner(@user)

      @project = create(:project, :repository, namespace: group, approvals_before_merge: 1, reset_approvals_on_push: true)
      @fork_project = fork_project(@project, @user, repository: true)

      @merge_request = create(:merge_request,
                              source_project: @project,
                              source_branch: 'master',
                              target_branch: 'feature',
                              target_project: @project,
                              merge_when_pipeline_succeeds: true,
                              merge_user: @user)

      @another_merge_request = create(:merge_request,
                                      source_project: @project,
                                      source_branch: 'master',
                                      target_branch: 'test',
                                      target_project: @project,
                                      merge_when_pipeline_succeeds: true,
                                      merge_user: @user)

      @fork_merge_request = create(:merge_request,
                                   source_project: @fork_project,
                                   source_branch: 'master',
                                   target_branch: 'feature',
                                   target_project: @project)

      @merge_request.approvals.create(user_id: user.id)
      @fork_merge_request.approvals.create(user_id: user.id)

      @build_failed_todo = create(:todo,
                                  :build_failed,
                                  user: @user,
                                  project: @project,
                                  target: @merge_request,
                                  author: @user)

      @fork_build_failed_todo = create(:todo,
                                       :build_failed,
                                       user: @user,
                                       project: @project,
                                       target: @merge_request,
                                       author: @user)

      @commits = @merge_request.commits

      @oldrev = @commits.last.id
      @newrev = @commits.first.id
    end

    context 'push to origin repo source branch' do
      let(:refresh_service) { service.new(@project, @user) }
      let(:notification_service) { spy('notification_service') }

      before do
        allow(refresh_service).to receive(:execute_hooks)
        allow(NotificationService).to receive(:new) { notification_service }
      end

      it 'executes hooks with update action' do
        refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
        reload_mrs

        expect(refresh_service).to have_received(:execute_hooks)
          .with(@merge_request, 'update', old_rev: @oldrev)

        expect(notification_service).to have_received(:push_to_merge_request)
          .with(@merge_request, @user, new_commits: anything, existing_commits: anything)
        expect(notification_service).to have_received(:push_to_merge_request)
          .with(@another_merge_request, @user, new_commits: anything, existing_commits: anything)

        expect(@merge_request.notes).not_to be_empty
        expect(@merge_request).to be_open
        expect(@merge_request.merge_when_pipeline_succeeds).to be_falsey
        expect(@merge_request.diff_head_sha).to eq(@newrev)
        expect(@fork_merge_request).to be_open
        expect(@fork_merge_request.notes).to be_empty
        expect(@build_failed_todo).to be_done
        expect(@fork_build_failed_todo).to be_done
        # EE-only
        expect(@merge_request.approvals).to be_empty
        expect(@fork_merge_request.approvals).not_to be_empty
      end

      it 'reloads source branch MRs memoization' do
        refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')

        expect { refresh_service.execute(@oldrev, @newrev, 'refs/heads/master') }.to change {
          refresh_service.instance_variable_get("@source_merge_requests").first.merge_request_diff
        }
      end

      context 'when source branch ref does not exists' do
        before do
          DeleteBranchService.new(@project, @user).execute(@merge_request.source_branch)
        end

        it 'closes MRs without source branch ref' do
          expect { refresh_service.execute(@oldrev, @newrev, 'refs/heads/master') }
            .to change { @merge_request.reload.state }
            .from('opened')
            .to('closed')

          expect(@fork_merge_request.reload).to be_open
        end

        it 'does not change the merge request diff' do
          expect { refresh_service.execute(@oldrev, @newrev, 'refs/heads/master') }
            .not_to change { @merge_request.reload.merge_request_diff }
        end
      end
    end

    context 'when pipeline exists for the source branch' do
      let!(:pipeline) { create(:ci_empty_pipeline, ref: @merge_request.source_branch, project: @project, sha: @commits.first.sha)}

      subject { service.new(@project, @user).execute(@oldrev, @newrev, 'refs/heads/master') }

      it 'updates the head_pipeline_id for @merge_request' do
        expect { subject }.to change { @merge_request.reload.head_pipeline_id }.from(nil).to(pipeline.id)
      end

      it 'does not update the head_pipeline_id for @fork_merge_request' do
        expect { subject }.not_to change { @fork_merge_request.reload.head_pipeline_id }
      end
    end

    describe 'Merge request pipelines' do
      before do
        stub_ci_pipeline_yaml_file(YAML.dump(config))
      end

      subject { service.new(@project, @user).execute(@oldrev, @newrev, 'refs/heads/master') }

      context "when .gitlab-ci.yml has merge_requests keywords" do
        let(:config) do
          {
            test: {
              stage: 'test',
              script: 'echo',
              only: ['merge_requests']
            }
          }
        end

        it 'create merge request pipeline with commits' do
          expect { subject }
            .to change { @merge_request.merge_request_pipelines.count }.by(1)
            .and change { @fork_merge_request.merge_request_pipelines.count }.by(1)
            .and change { @another_merge_request.merge_request_pipelines.count }.by(0)

          expect(@merge_request.has_commits?).to be_truthy
          expect(@fork_merge_request.has_commits?).to be_truthy
          expect(@another_merge_request.has_commits?).to be_falsy
        end

        context "when branch pipeline was created before a merge request pipline has been created" do
          before do
            create(:ci_pipeline, project: @merge_request.source_project,
                                 sha: @merge_request.diff_head_sha,
                                 ref: @merge_request.source_branch,
                                 tag: false)

            subject
          end

          it 'sets the latest merge request pipeline as a head pipeline' do
            @merge_request.reload
            expect(@merge_request.actual_head_pipeline).to be_merge_request
          end

          it 'returns pipelines in correct order' do
            @merge_request.reload
            expect(@merge_request.all_pipelines.first).to be_merge_request
            expect(@merge_request.all_pipelines.second).to be_push
          end
        end

        context "when MergeRequestUpdateWorker is retried by an exception" do
          it 'does not re-create a duplicate merge request pipeline' do
            expect do
              service.new(@project, @user).execute(@oldrev, @newrev, 'refs/heads/master')
            end.to change { @merge_request.merge_request_pipelines.count }.by(1)

            expect do
              service.new(@project, @user).execute(@oldrev, @newrev, 'refs/heads/master')
            end.not_to change { @merge_request.merge_request_pipelines.count }
          end
        end

        context "when the 'ci_merge_request_pipeline' feature flag is disabled" do
          before do
            stub_feature_flags(ci_merge_request_pipeline: false)
          end

          it 'does not create a merge request pipeline' do
            expect { subject }
              .not_to change { @merge_request.merge_request_pipelines.count }
          end
        end
      end

      context "when .gitlab-ci.yml does not have merge_requests keywords" do
        let(:config) do
          {
            test: {
              stage: 'test',
              script: 'echo'
            }
          }
        end

        it 'does not create a merge request pipeline' do
          expect { subject }
            .not_to change { @merge_request.merge_request_pipelines.count }
        end
      end
    end

    context 'push to origin repo source branch when an MR was reopened' do
      let(:refresh_service) { service.new(@project, @user) }
      let(:notification_service) { spy('notification_service') }

      before do
        @merge_request.update(state: :opened)

        allow(refresh_service).to receive(:execute_hooks)
        allow(NotificationService).to receive(:new) { notification_service }
        refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
        reload_mrs
      end

      it 'executes hooks with update action' do
        expect(refresh_service).to have_received(:execute_hooks)
          .with(@merge_request, 'update', old_rev: @oldrev)
        expect(notification_service).to have_received(:push_to_merge_request)
          .with(@merge_request, @user, new_commits: anything, existing_commits: anything)
        expect(notification_service).to have_received(:push_to_merge_request)
          .with(@another_merge_request, @user, new_commits: anything, existing_commits: anything)

        expect(@merge_request.notes).not_to be_empty
        expect(@merge_request).to be_open
        expect(@merge_request.merge_when_pipeline_succeeds).to be_falsey
        expect(@merge_request.diff_head_sha).to eq(@newrev)
        expect(@fork_merge_request).to be_open
        expect(@fork_merge_request.notes).to be_empty
        expect(@build_failed_todo).to be_done
        expect(@fork_build_failed_todo).to be_done
      end
    end

    context 'push to origin repo target branch' do
      context 'when all MRs to the target branch had diffs' do
        before do
          service.new(@project, @user).execute(@oldrev, @newrev, 'refs/heads/feature')
          reload_mrs
        end

        it 'updates the merge state' do
          expect(@merge_request.notes.last.note).to include('merged')
          expect(@merge_request).to be_merged
          expect(@fork_merge_request).to be_merged
          expect(@fork_merge_request.notes.last.note).to include('merged')
          expect(@build_failed_todo).to be_done
          expect(@fork_build_failed_todo).to be_done
          # EE-only
          expect(@merge_request.approvals).not_to be_empty
          expect(@fork_merge_request.approvals).not_to be_empty
        end
      end

      context 'when an MR to be closed was empty already' do
        let!(:empty_fork_merge_request) do
          create(:merge_request,
                 source_project: @fork_project,
                 source_branch: 'master',
                 target_branch: 'master',
                 target_project: @project)
        end

        before do
          # This spec already has a fake push, so pretend that we were targeting
          # feature all along.
          empty_fork_merge_request.update_columns(target_branch: 'feature')

          service.new(@project, @user).execute(@oldrev, @newrev, 'refs/heads/feature')
          reload_mrs
          empty_fork_merge_request.reload
        end

        it 'only updates the non-empty MRs' do
          expect(@merge_request).to be_merged
          expect(@merge_request.notes.last.note).to include('merged')

          expect(@fork_merge_request).to be_merged
          expect(@fork_merge_request.notes.last.note).to include('merged')

          expect(empty_fork_merge_request).to be_open
          expect(empty_fork_merge_request.merge_request_diff.state).to eq('empty')
          expect(empty_fork_merge_request.notes).to be_empty
        end
      end
    end

    context 'manual merge of source branch' do
      before do
        # Merge master -> feature branch
        @project.repository.merge(@user, @merge_request.diff_head_sha, @merge_request, 'Test message')
        commit = @project.repository.commit('feature')
        service.new(@project, @user).execute(@oldrev, commit.id, 'refs/heads/feature')
        reload_mrs
      end

      it 'updates the merge state' do
        expect(@merge_request.notes.last.note).to include('merged')
        expect(@merge_request).to be_merged
        expect(@merge_request.diffs.size).to be > 0
        expect(@fork_merge_request).to be_merged
        expect(@fork_merge_request.notes.last.note).to include('merged')
        expect(@build_failed_todo).to be_done
        expect(@fork_build_failed_todo).to be_done
      end
    end

    context 'push to fork repo source branch' do
      let(:refresh_service) { service.new(@fork_project, @user) }

      context 'open fork merge request' do
        before do
          allow(refresh_service).to receive(:execute_hooks)
          refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
          reload_mrs
        end

        it 'executes hooks with update action' do
          expect(refresh_service).to have_received(:execute_hooks)
            .with(@fork_merge_request, 'update', old_rev: @oldrev)

          expect(@merge_request.notes).to be_empty
          expect(@merge_request).to be_open
          expect(@fork_merge_request.notes.last.note).to include('added 28 commits')
          expect(@fork_merge_request).to be_open
          expect(@build_failed_todo).to be_pending
          expect(@fork_build_failed_todo).to be_pending
          # EE-only
          expect(@merge_request.approvals).not_to be_empty
          expect(@fork_merge_request.approvals).to be_empty
        end
      end

      context 'closed fork merge request' do
        before do
          @fork_merge_request.close!
          allow(refresh_service).to receive(:execute_hooks)
          refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
          reload_mrs
        end

        it 'do not execute hooks with update action' do
          expect(refresh_service).not_to have_received(:execute_hooks)
        end

        it 'updates merge request to closed state' do
          expect(@merge_request.notes).to be_empty
          expect(@merge_request).to be_open
          expect(@fork_merge_request.notes).to be_empty
          expect(@fork_merge_request).to be_closed
          expect(@build_failed_todo).to be_pending
          expect(@fork_build_failed_todo).to be_pending
          # EE-only
          expect(@merge_request.approvals).not_to be_empty
          expect(@fork_merge_request.approvals).to be_empty
        end
      end
    end

    context 'push to fork repo target branch' do
      describe 'changes to merge requests' do
        before do
          service.new(@fork_project, @user).execute(@oldrev, @newrev, 'refs/heads/feature')
          reload_mrs
        end

        it 'updates the merge request state' do
          expect(@merge_request.notes).to be_empty
          expect(@merge_request).to be_open
          expect(@fork_merge_request.notes).to be_empty
          expect(@fork_merge_request).to be_open
          expect(@build_failed_todo).to be_pending
          expect(@fork_build_failed_todo).to be_pending
          # EE-only
          expect(@merge_request.approvals).not_to be_empty
          expect(@fork_merge_request.approvals).not_to be_empty
        end
      end

      describe 'merge request diff' do
        it 'does not reload the diff of the merge request made from fork' do
          expect do
            service.new(@fork_project, @user).execute(@oldrev, @newrev, 'refs/heads/feature')
          end.not_to change { @fork_merge_request.reload.merge_request_diff }
        end
      end
    end

    context 'forked projects with the same source branch name as target branch' do
      let!(:first_commit) do
        @fork_project.repository.create_file(@user, 'test1.txt', 'Test data',
                                             message: 'Test commit',
                                             branch_name: 'master')
      end
      let!(:second_commit) do
        @fork_project.repository.create_file(@user, 'test2.txt', 'More test data',
                                             message: 'Second test commit',
                                             branch_name: 'master')
      end
      let!(:forked_master_mr) do
        create(:merge_request,
               source_project: @fork_project,
               source_branch: 'master',
               target_branch: 'master',
               target_project: @project)
      end
      let(:force_push_commit) { @project.commit('feature').id }

      it 'should reload a new diff for a push to the forked project' do
        expect do
          service.new(@fork_project, @user).execute(@oldrev, first_commit, 'refs/heads/master')
          reload_mrs
        end.to change { forked_master_mr.merge_request_diffs.count }.by(1)
      end

      it 'should reload a new diff for a force push to the source branch' do
        expect do
          service.new(@fork_project, @user).execute(@oldrev, force_push_commit, 'refs/heads/master')
          reload_mrs
        end.to change { forked_master_mr.merge_request_diffs.count }.by(1)
      end

      it 'should reload a new diff for a force push to the target branch' do
        expect do
          service.new(@project, @user).execute(@oldrev, force_push_commit, 'refs/heads/master')
          reload_mrs
        end.to change { forked_master_mr.merge_request_diffs.count }.by(1)
      end

      it 'should reload a new diff for a push to the target project that contains a commit in the MR' do
        expect do
          service.new(@project, @user).execute(@oldrev, first_commit, 'refs/heads/master')
          reload_mrs
        end.to change { forked_master_mr.merge_request_diffs.count }.by(1)
      end

      it 'should not increase the diff count for a new push to target branch' do
        new_commit = @project.repository.create_file(@user, 'new-file.txt', 'A new file',
                                                     message: 'This is a test',
                                                     branch_name: 'master')

        expect do
          service.new(@project, @user).execute(@newrev, new_commit, 'refs/heads/master')
          reload_mrs
        end.not_to change { forked_master_mr.merge_request_diffs.count }
      end
    end

    context 'push to origin repo target branch after fork project was removed' do
      before do
        @fork_project.destroy
        service.new(@project, @user).execute(@oldrev, @newrev, 'refs/heads/feature')
        reload_mrs
      end

      it 'updates the merge request state' do
        expect(@merge_request.notes.last.note).to include('merged')
        expect(@merge_request).to be_merged
        expect(@fork_merge_request).to be_open
        expect(@fork_merge_request.notes).to be_empty
        expect(@build_failed_todo).to be_done
        expect(@fork_build_failed_todo).to be_done
        # EE-only
        expect(@merge_request.approvals).not_to be_empty
        expect(@fork_merge_request.approvals).not_to be_empty
      end
    end

    context 'resetting approvals if they are enabled' do
      context 'when approvals_before_merge is disabled' do
        before do
          @project.update(approvals_before_merge: 0)
          refresh_service = service.new(@project, @user)
          allow(refresh_service).to receive(:execute_hooks)
          refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
          reload_mrs
        end

        it 'resets approvals' do
          expect(@merge_request.approvals).to be_empty
        end
      end

      context 'when reset_approvals_on_push is disabled' do
        before do
          @project.update(reset_approvals_on_push: false)
          refresh_service = service.new(@project, @user)
          allow(refresh_service).to receive(:execute_hooks)
          refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
          reload_mrs
        end

        it 'does not reset approvals' do
          expect(@merge_request.approvals).not_to be_empty
        end
      end

      context 'when the rebase_commit_sha on the MR matches the pushed SHA' do
        before do
          @merge_request.update(rebase_commit_sha: @newrev)
          refresh_service = service.new(@project, @user)
          allow(refresh_service).to receive(:execute_hooks)
          refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
          reload_mrs
        end

        it 'does not reset approvals' do
          expect(@merge_request.approvals).not_to be_empty
        end
      end

      context 'when there are approvals' do
        context 'closed merge request' do
          before do
            @merge_request.close!
            refresh_service = service.new(@project, @user)
            allow(refresh_service).to receive(:execute_hooks)
            refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'resets the approvals' do
            expect(@merge_request.approvals).to be_empty
          end
        end

        context 'opened merge request' do
          before do
            refresh_service = service.new(@project, @user)
            allow(refresh_service).to receive(:execute_hooks)
            refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'resets the approvals' do
            expect(@merge_request.approvals).to be_empty
          end
        end
      end
    end

    context 'push new branch that exists in a merge request' do
      let(:refresh_service) { service.new(@fork_project, @user) }

      it 'refreshes the merge request' do
        expect(refresh_service).to receive(:execute_hooks)
                                       .with(@fork_merge_request, 'update', old_rev: Gitlab::Git::BLANK_SHA)
        allow_any_instance_of(Repository).to receive(:merge_base).and_return(@oldrev)

        refresh_service.execute(Gitlab::Git::BLANK_SHA, @newrev, 'refs/heads/master')
        reload_mrs

        expect(@merge_request.notes).to be_empty
        expect(@merge_request).to be_open

        notes = @fork_merge_request.notes.reorder(:created_at).map(&:note)
        expect(notes[0]).to include('restored source branch `master`')
        expect(notes[1]).to include('added 28 commits')
        expect(@fork_merge_request).to be_open
      end
    end

    context 'merge request metrics' do
      let(:issue) { create :issue, project: @project }
      let(:commit_author) { create :user }
      let(:commit) { project.commit }

      before do
        project.add_developer(commit_author)
        project.add_developer(user)

        allow(commit).to receive_messages(
          safe_message: "Closes #{issue.to_reference}",
          references: [issue],
          author_name: commit_author.name,
          author_email: commit_author.email,
          committed_date: Time.now
        )

        allow_any_instance_of(MergeRequest).to receive(:commits).and_return(CommitCollection.new(@project, [commit], 'feature'))
      end

      context 'when the merge request is sourced from the same project' do
        it 'creates a `MergeRequestsClosingIssues` record for each issue closed by a commit' do
          merge_request = create(:merge_request, target_branch: 'master', source_branch: 'feature', source_project: @project)
          refresh_service = service.new(@project, @user)
          allow(refresh_service).to receive(:execute_hooks)
          refresh_service.execute(@oldrev, @newrev, 'refs/heads/feature')

          issue_ids = MergeRequestsClosingIssues.where(merge_request: merge_request).pluck(:issue_id)
          expect(issue_ids).to eq([issue.id])
        end
      end

      context 'when the merge request is sourced from a different project' do
        it 'creates a `MergeRequestsClosingIssues` record for each issue closed by a commit' do
          forked_project = fork_project(@project, @user, repository: true)

          merge_request = create(:merge_request,
                                 target_branch: 'master',
                                 source_branch: 'feature',
                                 target_project: @project,
                                 source_project: forked_project)
          refresh_service = service.new(@project, @user)
          allow(refresh_service).to receive(:execute_hooks)
          refresh_service.execute(@oldrev, @newrev, 'refs/heads/feature')

          issue_ids = MergeRequestsClosingIssues.where(merge_request: merge_request).pluck(:issue_id)
          expect(issue_ids).to eq([issue.id])
        end
      end
    end

    context 'marking the merge request as work in progress' do
      let(:refresh_service) { service.new(@project, @user) }
      before do
        allow(refresh_service).to receive(:execute_hooks)
      end

      it 'marks the merge request as work in progress from fixup commits' do
        fixup_merge_request = create(:merge_request,
                                     source_project: @project,
                                     source_branch: 'wip',
                                     target_branch: 'master',
                                     target_project: @project)
        commits = fixup_merge_request.commits
        oldrev = commits.last.id
        newrev = commits.first.id

        refresh_service.execute(oldrev, newrev, 'refs/heads/wip')
        fixup_merge_request.reload

        expect(fixup_merge_request.work_in_progress?).to eq(true)
        expect(fixup_merge_request.notes.last.note).to match(
          /marked as a \*\*Work In Progress\*\* from #{Commit.reference_pattern}/
        )
      end

      it 'references the commit that caused the Work in Progress status' do
        wip_merge_request = create(:merge_request,
                                   source_project: @project,
                                   source_branch: 'wip',
                                   target_branch: 'master',
                                   target_project: @project)

        commits = wip_merge_request.commits
        oldrev = commits.last.id
        newrev = commits.first.id
        wip_commit = wip_merge_request.commits.find(&:work_in_progress?)

        refresh_service.execute(oldrev, newrev, 'refs/heads/wip')

        expect(wip_merge_request.reload.notes.last.note).to eq(
          "marked as a **Work In Progress** from #{wip_commit.id}"
        )
      end

      it 'does not mark as WIP based on commits that do not belong to an MR' do
        allow(refresh_service).to receive(:find_new_commits)
        refresh_service.instance_variable_set("@commits", [
          double(
            id: 'aaaaaaa',
            sha: 'aaaaaaa',
            short_id: 'aaaaaaa',
            title: 'Fix issue',
            work_in_progress?: false
          ),
          double(
            id: 'bbbbbbb',
            sha: 'bbbbbbbb',
            short_id: 'bbbbbbb',
            title: 'fixup! Fix issue',
            work_in_progress?: true,
            to_reference: 'bbbbbbb'
          )
        ])

        refresh_service.execute(@oldrev, @newrev, 'refs/heads/master')
        reload_mrs

        expect(@merge_request.work_in_progress?).to be_falsey
      end
    end

    def reload_mrs
      @merge_request.reload
      @fork_merge_request.reload
      @build_failed_todo.reload
      @fork_build_failed_todo.reload
    end
  end

  describe 'updating merge_commit' do
    let(:service) { described_class.new(project, user) }
    let(:user) { create(:user) }
    let(:project) { create(:project, :repository) }

    let(:oldrev) { TestEnv::BRANCH_SHA['merge-commit-analyze-before'] }
    let(:newrev) { TestEnv::BRANCH_SHA['merge-commit-analyze-after'] } # Pretend branch is now updated

    let!(:merge_request) do
      create(
        :merge_request,
        source_project: project,
        source_branch: 'merge-commit-analyze-after',
        target_branch: 'merge-commit-analyze-before',
        target_project: project,
        merge_user: user
      )
    end

    let!(:merge_request_side_branch) do
      create(
        :merge_request,
        source_project: project,
        source_branch: 'merge-commit-analyze-side-branch',
        target_branch: 'merge-commit-analyze-before',
        target_project: project,
        merge_user: user
      )
    end

    subject { service.execute(oldrev, newrev, 'refs/heads/merge-commit-analyze-before') }

    context 'feature enabled' do
      before do
        stub_feature_flags(branch_push_merge_commit_analyze: true)
      end

      it "updates merge requests' merge_commits" do
        expect(Gitlab::BranchPushMergeCommitAnalyzer).to receive(:new).and_wrap_original do |original_method, commits|
          expect(commits.map(&:id)).to eq(%w{646ece5cfed840eca0a4feb21bcd6a81bb19bda3 29284d9bcc350bcae005872d0be6edd016e2efb5 5f82584f0a907f3b30cfce5bb8df371454a90051 8a994512e8c8f0dfcf22bb16df6e876be7a61036 689600b91aabec706e657e38ea706ece1ee8268f db46a1c5a5e474aa169b6cdb7a522d891bc4c5f9})

          original_method.call(commits)
        end

        subject

        merge_request.reload
        merge_request_side_branch.reload

        expect(merge_request.merge_commit.id).to eq('646ece5cfed840eca0a4feb21bcd6a81bb19bda3')
        expect(merge_request_side_branch.merge_commit.id).to eq('29284d9bcc350bcae005872d0be6edd016e2efb5')
      end
    end

    context 'when feature is disabled' do
      before do
        stub_feature_flags(branch_push_merge_commit_analyze: false)
      end

      it "does not trigger analysis" do
        expect(Gitlab::BranchPushMergeCommitAnalyzer).not_to receive(:new)

        subject

        merge_request.reload
        merge_request_side_branch.reload

        expect(merge_request.merge_commit).to eq(nil)
        expect(merge_request_side_branch.merge_commit).to eq(nil)
      end
    end
  end
end
