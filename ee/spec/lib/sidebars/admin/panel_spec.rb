# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Panel, feature_category: :navigation do
  let_it_be(:user) { build(:admin) }

  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

  before do
    stub_licensed_features(
      custom_roles: true,
      admin_audit_log: true,
      custom_file_templates: true,
      elastic_search: true,
      license_scanning: true
    )
    stub_application_setting(grafana_enabled: true)
  end

  subject { described_class.new(context) }

  it_behaves_like 'a panel with uniquely identifiable menu items'
  it_behaves_like 'a panel without placeholders'
  it_behaves_like 'a panel instantiable by the anonymous user'

  shared_examples 'hides code suggestions menu' do
    it 'does not render code suggestions menu' do
      expect(menus).not_to include(instance_of(::Sidebars::Admin::Menus::CodeSuggestionsMenu))
    end
  end

  describe '#configure_menus' do
    let(:menus) { subject.instance_variable_get(:@menus) }

    context 'when instance is self-managed' do
      before do
        stub_saas_features(gitlab_saas_subscriptions: false)
      end

      context 'when self_managed_code_suggestions feature flag is enabled' do
        it 'renders code suggestions menu' do
          expect(menus).to include(instance_of(::Sidebars::Admin::Menus::CodeSuggestionsMenu))
        end
      end

      context 'when self_managed_code_suggestions feature flag is disabled' do
        before do
          stub_feature_flags(self_managed_code_suggestions: false)
        end

        it_behaves_like 'hides code suggestions menu'
      end
    end

    context 'when instance is SaaS' do
      where(:self_managed_code_suggestions) do
        [true, false]
      end

      with_them do
        before do
          stub_saas_features(gitlab_saas_subscriptions: true)
          stub_feature_flags(self_managed_code_suggestions: self_managed_code_suggestions)
        end

        it_behaves_like 'hides code suggestions menu'
      end
    end
  end
end
