# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Analytics::CycleAnalytics::ValueStreamsController, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:another_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:namespace) { group }

  let(:path_prefix) { %i[group] }
  let(:params) { { group_id: group.to_param } }
  let(:license_name) { :cycle_analytics_for_groups }

  it_behaves_like 'value stream controller actions'

  describe 'value stream settings' do
    before_all do
      group.add_developer(user)
    end

    before do
      stub_licensed_features(cycle_analytics_for_groups: true)
      login_as(user)
    end

    context 'when updating' do
      let_it_be_with_refind(:value_stream) do
        create(
          :cycle_analytics_value_stream,
          namespace: group,
          name: 'A value stream'
        )
      end

      let(:value_stream_params) do
        { name: 'renamed', setting: { project_ids_filter: [3, 4] } }
      end

      subject(:request) { put path_for(value_stream), params: { value_stream: value_stream_params } }

      it 'updates project ids filter array' do
        value_stream.update!(setting_attributes: { project_ids_filter: [1, 2] })

        expect { request }
          .to change { value_stream.reload.setting.project_ids_filter }
          .from([1, 2])
          .to([3, 4])
      end

      context 'when project ids filter parameter is empty' do
        let(:value_stream_params) do
          { name: 'renamed', setting: { project_ids_filter: [] } }
        end

        it 'clears the filter' do
          value_stream.update!(setting_attributes: { project_ids_filter: [1, 2] })

          expect { request }
            .to change { value_stream.reload.setting.project_ids_filter }
            .from([1, 2])
            .to(nil)
        end
      end
    end

    context 'when creating' do
      let(:value_stream_params) do
        { name: 'New Stream', setting: { project_ids_filter: [1, 2] } }
      end

      subject(:request) do
        post path_for(%i[analytics cycle_analytics value_streams]), params: { value_stream: value_stream_params }
      end

      it 'saves value stream setting' do
        request

        value_stream = Analytics::CycleAnalytics::ValueStream.last
        expect(response).to have_gitlab_http_status(:created)
        expect(value_stream.setting).to be_persisted
        expect(value_stream.setting.project_ids_filter).to eq([1, 2])
      end
    end
  end

  def path_for(path_postfix)
    Rails.application.routes.url_helpers.polymorphic_path(path_prefix + Array(path_postfix), **params)
  end
end
