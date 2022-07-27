# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiProjectVariable'] do
  specify { expect(described_class.interfaces).to contain_exactly(Types::Ci::VariableInterface) }

  it { expect(described_class).to have_graphql_fields(:environment_scope).at_least }
end
