# frozen_string_literal: true

RSpec.shared_examples 'does not enqueue a worker to sync a metadata cache' do
  it 'does not enqueue a worker to sync a metadata cache' do
    expect(Packages::Npm::CreateMetadataCacheWorker).not_to receive(:perform_async)

    subject
  end
end

RSpec.shared_examples 'enqueue a worker to sync a metadata cache' do
  before do
    project.add_maintainer(user)
  end

  it 'enqueues a worker to create a metadata cache' do
    expect(Packages::Npm::CreateMetadataCacheWorker)
      .to receive(:perform_async).with(project.id, package_name)

    subject
  end

  context 'with npm_metadata_cache disabled' do
    before do
      stub_feature_flags(npm_metadata_cache: false)
    end

    it_behaves_like 'does not enqueue a worker to sync a metadata cache'
  end
end
