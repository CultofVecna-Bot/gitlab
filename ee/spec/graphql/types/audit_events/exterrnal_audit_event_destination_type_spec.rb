# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ExternalAuditEventDestination'] do
  let(:fields) do
    %i[id destination_url group verification_token headers]
  end

  specify { expect(described_class.graphql_name).to eq('ExternalAuditEventDestination') }
  specify { expect(described_class).to have_graphql_fields(fields) }
  specify { expect(described_class).to require_graphql_authorizations(:admin_external_audit_events) }

  context 'streaming_audit_event_headers flag is disabled' do
    before do
      stub_feature_flags(streaming_audit_event_headers: false)
    end

    specify { expect(described_class).to have_graphql_fields(fields - ['headers']) }
  end
end
