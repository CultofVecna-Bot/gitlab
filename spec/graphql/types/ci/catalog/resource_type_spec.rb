# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::Catalog::ResourceType, feature_category: :pipeline_composition do
  specify { expect(described_class.graphql_name).to eq('CiCatalogResource') }

  it 'exposes the expected fields' do
    expected_fields = %i[
      id
      name
      description
      icon
      web_path
      versions
      star_count
      forks_count
      root_namespace
      readme_html
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
