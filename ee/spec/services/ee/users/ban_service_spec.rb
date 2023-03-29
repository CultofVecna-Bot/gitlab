# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::BanService, feature_category: :user_management do
  let_it_be(:current_user) { create(:admin) }

  subject(:service) { described_class.new(current_user) }

  describe '#execute' do
    let!(:user) { create(:user) }

    subject(:operation) { service.execute(user) }

    describe 'audit events' do
      context 'when licensed', :enable_admin_mode do
        before do
          stub_licensed_features(admin_audit_log: true)
        end

        context 'when user ban operation succeeds' do
          it 'logs an audit event' do
            expect { operation }.to change { AuditEvent.count }.by(1)
          end

          it 'logs the audit event info' do
            operation
            expect(AuditEvent.last).to have_attributes(
              details: hash_including(custom_message: 'Banned user')
            )
          end
        end

        context 'when user ban operation fails' do
          let!(:user) { create(:user) }

          before do
            allow(user).to receive(:ban).and_return(false)
          end

          it 'does not log any audit event' do
            expect { operation }.not_to change { AuditEvent.count }
          end
        end
      end

      context 'when not licensed' do
        before do
          stub_licensed_features(
            admin_audit_log: false,
            audit_events: false,
            extended_audit_events: false
          )
        end

        it 'does not log any audit event' do
          expect { operation }.not_to change { AuditEvent.count }
        end
      end
    end
  end
end
