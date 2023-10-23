# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Search::Zoekt, feature_category: :global_search do
  include GitlabShellHelpers
  include APIInternalBaseHelpers

  describe 'GET /internal/search/zoekt/:uuid/tasks' do
    let(:endpoint) { "/internal/search/zoekt/#{uuid}/tasks" }
    let(:uuid) { '3869fe21-36d1-4612-9676-0b783ef2dcd7' }
    let(:valid_params) do
      {
        'uuid' => uuid,
        'node.url' => 'http://localhost:6090',
        'node.name' => 'm1.local',
        'disk.all' => 994662584320,
        'disk.used' => 532673712128,
        'disk.free' => 461988872192
      }
    end

    context 'with invalid auth' do
      it 'returns 401' do
        get api(endpoint),
          params: valid_params,
          headers: gitlab_shell_internal_api_request_header(issuer: 'gitlab-workhorse')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'with valid auth' do
      context 'when a task request is received with valid params' do
        it 'returns node ID for task request' do
          node = instance_double(::Search::Zoekt::Node, id: 123)
          expect(::Search::Zoekt::Node).to receive(:find_or_initialize_by_task_request)
            .with(valid_params).and_return(node)
          expect(node).to receive(:save).and_return(true)

          get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({ 'id' => node.id })
        end
      end

      context 'when a heartbeat has valid params but a node validation error occurs' do
        it 'returns 422' do
          node = ::Search::Zoekt::Node.new(search_base_url: nil) # null attributes makes this invalid
          expect(::Search::Zoekt::Node).to receive(:find_or_initialize_by_task_request)
            .with(valid_params).and_return(node)
          get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'when a heartbeat is received with invalid params' do
        it 'returns 400' do
          get api(endpoint), params: { 'foo' => 'bar' }, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end
end
