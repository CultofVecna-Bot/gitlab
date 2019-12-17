# frozen_string_literal: true

require 'spec_helper'

describe MergeRequestsComplianceFinder do
  subject { described_class.new(current_user, search_params) }

  let(:current_user) { create(:admin) }
  let(:search_params) { { group_id: group.id } }
  let(:group) { create(:group) }
  let(:project) { create(:project, namespace: group) }
  let(:project_2) { create(:project, namespace: group) }

  let(:mr_1) { create(:merge_request, source_project: project, state: :merged) }
  let(:mr_2) { create(:merge_request, source_project: project_2, state: :merged) }
  let(:mr_3) { create(:merge_request, source_project: project, source_branch: 'A', state: :merged) }
  let(:mr_4) { create(:merge_request, source_project: project_2, source_branch: 'A', state: :merged) }

  before do
    create(:event, :merged, project: project_2, target: mr_4, author: current_user, created_at: 50.minutes.ago, id: 1)
    create(:event, :merged, project: project_2, target: mr_2, author: current_user, created_at: 40.minutes.ago, id: 2)
    create(:event, :merged, project: project, target: mr_3, author: current_user, created_at: 30.minutes.ago, id: 3)
    create(:event, :merged, project: project, target: mr_1, author: current_user, created_at: 20.minutes.ago, id: 4)
  end

  context 'when there are merge requests from projects in group' do
    it 'shows only most recent Merge Request from each project' do
      expect(subject.execute).to contain_exactly(mr_1, mr_2)
    end

    it 'shows as many Merge Requests as they are projects with MR in group' do
      expect(subject.execute.size).to eq(group.projects.size)
    end

    context 'when there are merge requests from projects in group and subgroups' do
      let(:subgroup) { create(:group, parent: group) }
      let(:sub_project) { create(:project, namespace: subgroup) }

      let(:mr_5) { create(:merge_request, source_project: sub_project, state: :merged) }
      let(:mr_6) { create(:merge_request, source_project: sub_project, state: :merged) }

      before do
        create(:event, :merged, project: sub_project, target: mr_6, author: current_user, created_at: 30.minutes.ago, id: 6)
        create(:event, :merged, project: sub_project, target: mr_5, author: current_user, created_at: 10.minutes.ago, id: 7)
      end

      it 'shows only most recent Merge Request from each project' do
        expect(subject.execute).to contain_exactly(mr_1, mr_2, mr_5)
      end

      it 'shows Merge Requests from most recent to least recent' do
        expect(subject.execute).to eq([mr_5, mr_1, mr_2])
      end
    end
  end
end
