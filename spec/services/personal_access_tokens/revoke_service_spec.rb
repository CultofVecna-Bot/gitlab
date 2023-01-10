# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::RevokeService do
  shared_examples_for 'a successfully revoked token' do
    it { expect(subject.success?).to be true }
    it { expect(service.token.revoked?).to be true }

    it 'logs the event' do
      expect(Gitlab::AppLogger).to receive(:info).with(
        class: described_class.to_s,
        message: 'PAT Revoked',
        revoked_by: revoked_by,
        revoked_for: token.user.username,
        token_id: token.id)

      subject
    end
  end

  shared_examples_for 'an unsuccessfully revoked token' do
    it { expect(subject.success?).to be false }
    it { expect(service.token.revoked?).to be false }
  end

  describe '#execute' do
    subject { service.execute }

    let(:service) { described_class.new(current_user, token: token) }

    context 'when current_user is an administrator' do
      context 'when admin mode is enabled', :enable_admin_mode do
        let_it_be(:current_user) { create(:admin) }
        let_it_be(:token) { create(:personal_access_token) }

        it_behaves_like 'a successfully revoked token' do
          let(:revoked_by) { current_user.username }
        end
      end

      context 'when admin mode is disabled' do
        let_it_be(:current_user) { create(:admin) }
        let_it_be(:token) { create(:personal_access_token) }

        it_behaves_like 'an unsuccessfully revoked token'
      end
    end

    context 'when current_user is not an administrator' do
      let_it_be(:current_user) { create(:user) }

      context 'token belongs to a different user' do
        let_it_be(:token) { create(:personal_access_token) }

        it_behaves_like 'an unsuccessfully revoked token'
      end

      context 'token belongs to current_user' do
        let_it_be(:token) { create(:personal_access_token, user: current_user) }

        it_behaves_like 'a successfully revoked token' do
          let(:revoked_by) { current_user.username }
        end
      end
    end

    context 'when source' do
      let(:service) { described_class.new(nil, token: token, source: source) }

      let_it_be(:current_user) { nil }

      context 'when source is valid' do
        let_it_be(:source) { :secret_detection }
        let_it_be(:token) { create(:personal_access_token) }

        it_behaves_like 'a successfully revoked token' do
          let(:revoked_by) { :secret_detection }
        end
      end

      context 'when source is invalid' do
        let_it_be(:source) { :external_request }
        let_it_be(:token) { create(:personal_access_token) }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error ArgumentError
        end
      end

      context 'when source is missing' do
        let_it_be(:source) { nil }
        let_it_be(:token) { create(:personal_access_token) }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error ArgumentError
        end
      end
    end
  end
end
