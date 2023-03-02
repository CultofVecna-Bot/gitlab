# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PagesDeploymentRegistry, :geo, type: :model, feature_category: :geo_replication do
  let(:registry) { create(:geo_pages_deployment_registry) }

  specify 'factory is valid' do
    expect(registry).to be_valid
  end

  include_examples 'a Geo framework registry'
  include_examples 'a Geo verifiable registry'
  include_examples 'a Geo searchable registry'
end
