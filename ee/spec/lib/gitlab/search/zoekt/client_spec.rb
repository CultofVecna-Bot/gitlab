# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Search::Zoekt::Client, :zoekt, feature_category: :global_search do
  let_it_be(:project_1) { create(:project, :public, :repository) }
  let_it_be(:project_2) { create(:project, :public, :repository) }
  let_it_be(:project_3) { create(:project, :public, :repository) }
  let(:client) { described_class.new }

  shared_examples 'an authenticated zoekt request' do
    context 'when basicauth username and password are present' do
      let(:password_file) { Rails.root.join("tmp/tests/zoekt_password") }
      let(:username_file) { Rails.root.join("tmp/tests/zoekt_username") }

      before do
        username_file = Rails.root.join("tmp/tests/zoekt_username")
        File.write(username_file, "the-username\r") # Ensure trailing newline is ignored
        password_file = Rails.root.join("tmp/tests/zoekt_password")
        File.write(password_file, "the-password\r") # Ensure trailing newline is ignored
        stub_config(zoekt: { username_file: username_file, password_file: password_file })
      end

      after do
        File.delete(username_file)
        File.delete(password_file)
      end

      it 'sets those in the request' do
        expect(::Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(basic_auth: { username: 'the-username', password: 'the-password' }))
          .and_call_original

        make_request
      end
    end
  end

  describe '#search' do
    let(:project_ids) { [project_1.id, project_2.id] }
    let(:query) { 'use.*egex' }
    let(:shard_id) { Zoekt::Shard.last.id }

    subject { client.search(query, num: 10, project_ids: project_ids, shard_id: shard_id) }

    before do
      zoekt_ensure_project_indexed!(project_1)
      zoekt_ensure_project_indexed!(project_2)
      zoekt_ensure_project_indexed!(project_3)
    end

    it 'returns the matching files from all searched projects' do
      expect(subject[:Result][:Files].pluck(:FileName)).to include(
        "files/ruby/regex.rb", "files/markdown/ruby-style-guide.md"
      )

      expect(subject[:Result][:Files].map { |r| r[:Repository].to_i }.uniq).to contain_exactly(
        project_1.id, project_2.id
      )
    end

    context 'when there is no project_id filter' do
      let(:project_ids) { [] }

      it 'raises an error if there are somehow no project_id in the filter' do
        expect { subject }.to raise_error('Not possible to search without at least one project specified')
      end
    end

    context 'when project_id filter is any' do
      let(:project_ids) { :any }

      it 'raises an error if somehow :any is sent as project_ids' do
        expect { subject }.to raise_error('Global search is not supported')
      end
    end

    context 'with an invalid search' do
      let(:query) { '(invalid search(' }

      it 'logs an error and returns an empty array for results', :aggregate_failures do
        logger = instance_double(::Zoekt::Logger)
        expect(::Zoekt::Logger).to receive(:build).and_return(logger)
        expect(logger).to receive(:error).with(hash_including(status: 400))

        expect(subject[:Error]).to include('error parsing regexp')
      end
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { subject }
    end
  end

  describe '#index' do
    let(:shard_id) { Zoekt::Shard.last.id }

    it 'indexes the project to make it searchable' do
      search_results = client.search('use.*egex', num: 10, project_ids: [project_1.id], shard_id: shard_id)
      expect(search_results[:Result][:Files].to_a.size).to eq(0)

      client.index(project_1, shard_id)

      search_results = client.search('use.*egex', num: 10, project_ids: [project_1.id], shard_id: shard_id)
      expect(search_results[:Result][:Files].to_a.size).to be > 0
    end

    context 'when use_new_zoekt_indexer is disabled' do
      before do
        stub_feature_flags(use_new_zoekt_indexer: false)
      end

      it 'indexes using the old path' do
        expect(::Gitlab::HTTP).to receive(:post) do |url, args|
          body = args[:body]
          expect(url.to_s).to eq("#{::Zoekt::Shard.first.index_base_url}/index")
          body = ::Gitlab::Json.parse(body)

          expect(body["CloneUrl"]).to be_present
          expect(body["RepoId"]).to eq(project_1.id)
        end.and_return({})
        described_class.instance.index(project_1, shard_id)
      end
    end

    it 'raises an exception when indexing errors out' do
      allow(::Gitlab::HTTP).to receive(:post).and_return({ 'Error' => 'command failed: exit status 128' })

      expect do
        client.index(project_1, shard_id)
      end.to raise_error(RuntimeError, 'command failed: exit status 128')
    end

    it 'raises an exception when response is not successful' do
      response = {}
      allow(response).to receive(:success?).and_return(false)

      allow(::Gitlab::HTTP).to receive(:post).and_return(response)

      expect { client.index(project_1, shard_id) }.to raise_error(RuntimeError, /Request failed with/)
    end

    it 'sets http the correct timeout' do
      response = {}
      allow(response).to receive(:success?).and_return(true)

      expect(::Gitlab::HTTP).to receive(:post)
                                .with(anything, hash_including(timeout: described_class::INDEXING_TIMEOUT_S))
                                .and_return(response)
      client.index(project_1, shard_id)
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { client.index(project_1, shard_id) }
    end
  end

  describe '#delete' do
    subject { described_class.delete(shard_id: zoekt_shard.id, project_id: project_1.id) }

    context 'when project is indexed' do
      let(:shard_id) { Zoekt::Shard.last.id }

      before do
        zoekt_ensure_project_indexed!(project_1)
      end

      it 'removes project data from the Zoekt shard' do
        search_results = described_class.new.search('use.*egex', num: 10, project_ids: [project_1.id],
          shard_id: shard_id)
        expect(search_results[:Result][:Files].to_a.size).to eq(2)

        subject

        search_results = described_class.new.search('use.*egex', num: 10, project_ids: [project_1.id],
          shard_id: shard_id)
        expect(search_results[:Result][:Files].to_a).to be_empty
      end
    end

    context 'when use_new_zoekt_indexer is disabled' do
      before do
        stub_feature_flags(use_new_zoekt_indexer: false)
      end

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end

    context 'when request fails' do
      let(:response) { {} }

      before do
        zoekt_ensure_project_indexed!(project_1)
        allow(response).to receive(:success?).and_return(false)
        allow(::Gitlab::HTTP).to receive(:delete).and_return(response)
      end

      it 'raises and exception' do
        expect { subject }.to raise_error(StandardError, /Request failed/)
      end
    end
  end

  describe '#truncate' do
    let(:zoekt_indexer_truncate_path) { '/indexer/truncate' }
    let(:shard) { Zoekt::Shard.first }

    before do
      zoekt_ensure_project_indexed!(project_1)
      zoekt_ensure_project_indexed!(project_2)
    end

    it 'removes all data from the Zoekt shards' do
      search_results = client.search('use.*egex', num: 10, project_ids: [project_1.id], shard_id: shard.id)
      expect(search_results[:Result][:Files].to_a.size).to be > 0
      search_results = client.search('use.*egex', num: 10, project_ids: [project_2.id], shard_id: shard.id)
      expect(search_results[:Result][:Files].to_a.size).to be > 0

      client.truncate
      search_results = client.search('use.*egex', num: 10, project_ids: [project_1.id], shard_id: shard.id)
      expect(search_results[:Result][:Files].to_a.size).to eq(0)
      search_results = client.search('use.*egex', num: 10, project_ids: [project_2.id], shard_id: shard.id)
      expect(search_results[:Result][:Files].to_a.size).to eq(0)
    end

    it 'calls post on ::Gitlab::HTTP for all shards' do
      shard2 = create(:zoekt_shard)
      zoekt_truncate_path = '/indexer/truncate'
      expect(::Gitlab::HTTP).to receive(:post).with(URI.join(shard.index_base_url, zoekt_truncate_path), anything)
      expect(::Gitlab::HTTP).to receive(:post).with(URI.join(shard2.index_base_url, zoekt_truncate_path), anything)
      client.truncate
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { client.truncate }
    end
  end
end
