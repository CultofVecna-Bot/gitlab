require 'spec_helper'

describe "MergeRequest", elastic: true do
  before do
    allow(Gitlab.config.elasticsearch).to receive(:enabled).and_return(true)
    MergeRequest.__elasticsearch__.create_index!
  end

  after do
    allow(Gitlab.config.elasticsearch).to receive(:enabled).and_return(false)
    MergeRequest.__elasticsearch__.delete_index!
  end

  it "searches merge requests" do
    project = create :project

    create :merge_request, title: 'bla-bla term', source_project: project
    create :merge_request, description: 'term in description', source_project: project, target_branch: "feature2"
    create :merge_request, source_project: project, target_branch: "feature3"

    # The merge request you have no access to
    create :merge_request, title: 'also with term'

    MergeRequest.__elasticsearch__.refresh_index!

    options = { project_ids: [project.id] }

    expect(MergeRequest.elastic_search('term', options: options).total_count).to eq(2)
  end

  it "returns json with all needed elements" do
    merge_request = create :merge_request

    expected_hash =  merge_request.attributes.extract!(
      'id',
      'iid',
      'target_branch',
      'source_branch',
      'title',
      'description',
      'created_at',
      'updated_at',
      'state',
      'merge_status',
      'source_project_id',
      'target_project_id',
      'author_id'
    )

    expected_hash['updated_at_sort'] = merge_request.updated_at

    expect(merge_request.as_indexed_json).to eq(expected_hash)
  end
end
