require 'spec_helper'

describe API::V3::Labels, api: true  do
  include ApiHelpers

  let(:user) { create(:user) }
  let(:project) { create(:empty_project, creator_id: user.id, namespace: user.namespace) }
  let!(:label1) { create(:label, title: 'label1', project: project) }
  let!(:priority_label) { create(:label, title: 'bug', project: project, priority: 3) }

  before do
    project.team << [user, :master]
  end

  describe 'GET /projects/:id/labels' do
    it 'returns all available labels to the project' do
      group = create(:group)
      group_label = create(:group_label, title: 'feature', group: group)
      project.update(group: group)
      create(:labeled_issue, project: project, labels: [group_label], author: user)
      create(:labeled_issue, project: project, labels: [label1], author: user, state: :closed)
      create(:labeled_merge_request, labels: [priority_label], author: user, source_project: project )

      expected_keys = [
        'id', 'name', 'color', 'description',
        'open_issues_count', 'closed_issues_count', 'open_merge_requests_count',
        'subscribed', 'priority'
      ]

      get v3_api("/projects/#{project.id}/labels", user)

      expect(response).to have_http_status(200)
      expect(json_response).to be_an Array
      expect(json_response.size).to eq(3)
      expect(json_response.first.keys).to match_array expected_keys
      expect(json_response.map { |l| l['name'] }).to match_array([group_label.name, priority_label.name, label1.name])

      label1_response = json_response.find { |l| l['name'] == label1.title }
      group_label_response = json_response.find { |l| l['name'] == group_label.title }
      priority_label_response = json_response.find { |l| l['name'] == priority_label.title }

      expect(label1_response['open_issues_count']).to eq(0)
      expect(label1_response['closed_issues_count']).to eq(1)
      expect(label1_response['open_merge_requests_count']).to eq(0)
      expect(label1_response['name']).to eq(label1.name)
      expect(label1_response['color']).to be_present
      expect(label1_response['description']).to be_nil
      expect(label1_response['priority']).to be_nil
      expect(label1_response['subscribed']).to be_falsey

      expect(group_label_response['open_issues_count']).to eq(1)
      expect(group_label_response['closed_issues_count']).to eq(0)
      expect(group_label_response['open_merge_requests_count']).to eq(0)
      expect(group_label_response['name']).to eq(group_label.name)
      expect(group_label_response['color']).to be_present
      expect(group_label_response['description']).to be_nil
      expect(group_label_response['priority']).to be_nil
      expect(group_label_response['subscribed']).to be_falsey

      expect(priority_label_response['open_issues_count']).to eq(0)
      expect(priority_label_response['closed_issues_count']).to eq(0)
      expect(priority_label_response['open_merge_requests_count']).to eq(1)
      expect(priority_label_response['name']).to eq(priority_label.name)
      expect(priority_label_response['color']).to be_present
      expect(priority_label_response['description']).to be_nil
      expect(priority_label_response['priority']).to eq(3)
      expect(priority_label_response['subscribed']).to be_falsey
    end
  end
end
