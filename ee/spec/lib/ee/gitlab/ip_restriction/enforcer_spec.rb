# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::IpRestriction::Enforcer do
  describe '#allows_current_ip?' do
    let(:group) { create(:group) }
    let(:current_ip) { '192.168.0.2' }

    shared_examples 'ip_restriction' do
      context 'without restriction' do
        it { is_expected.to be_truthy }
      end

      context 'with restriction' do
        before do
          stub_feature_flags(group_ip_restrictions_allow_global: false)
          stub_application_setting(globally_allowed_ips: "10.0.0.0/8, 192.168.0.0/24")

          ranges.each do |range|
            create(:ip_restriction, group: group, range: range)
          end
        end

        context 'address is within one of the ranges' do
          let(:ranges) { ['192.168.0.0/24', '255.255.255.224/27'] }

          it { is_expected.to be_truthy }
        end

        context 'address is outside all of the ranges' do
          let(:ranges) { ['10.0.0.0/8', '255.255.255.224/27'] }

          it { is_expected.to be_falsey }
        end

        context 'global allowlist feature is enabled' do
          let(:current_ip) { '10.64.0.1' }
          let(:ranges) { ['192.168.1.0/24'] }

          before do
            stub_feature_flags(group_ip_restrictions_allow_global: group)
          end

          context 'global ranges are set' do
            it { is_expected.to be_truthy }
          end

          context 'global ranges are not set' do
            before do
              stub_application_setting(globally_allowed_ips: "")
            end

            it { is_expected.to be_falsey }
          end
        end
      end
    end

    subject { described_class.new(group).allows_current_ip? }

    before do
      allow(Gitlab::IpAddressState).to receive(:current).and_return(current_ip)
      stub_licensed_features(group_ip_restriction: true)
    end

    it_behaves_like 'ip_restriction'

    context 'group_ip_restriction feature is disabled' do
      before do
        stub_licensed_features(group_ip_restriction: false)
      end

      it { is_expected.to be_truthy }
    end

    context 'when usage ping is enabled' do
      before do
        stub_licensed_features(group_ip_restriction: false)
        stub_application_setting(usage_ping_enabled: true)
      end

      context 'when usage_ping_features_enabled is enabled' do
        before do
          stub_application_setting(usage_ping_features_enabled: true)
        end

        it_behaves_like 'ip_restriction'
      end

      context 'when usage_ping_features_enabled is disabled' do
        before do
          stub_application_setting(usage_ping_features_enabled: false)
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when usage ping is disabled' do
      before do
        stub_licensed_features(group_ip_restriction: false)
        stub_application_setting(usage_ping_enabled: false)
      end

      it { is_expected.to be_truthy }
    end
  end
end
