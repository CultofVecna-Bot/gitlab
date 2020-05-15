# frozen_string_literal: true

require 'spec_helper'

describe Resolvers::BaseResolver do
  include GraphqlHelpers

  let(:resolver) do
    Class.new(described_class) do
      def resolve(**args)
        process(object)

        [args, args]
      end

      def process(obj); end
    end
  end

  let(:last_resolver) do
    Class.new(described_class) do
      def resolve(**args)
        [1, 2]
      end
    end
  end

  describe '.single' do
    it 'returns a subclass from the resolver' do
      expect(resolver.single.superclass).to eq(resolver)
    end

    it 'returns the same subclass every time' do
      expect(resolver.single.object_id).to eq(resolver.single.object_id)
    end

    it 'returns a resolver that gives the first result from the original resolver' do
      result = resolve(resolver.single, args: { test: 1 })

      expect(result).to eq(test: 1)
    end
  end

  context 'when the resolver returns early' do
    let(:resolver) do
      Class.new(described_class) do
        def ready?(**args)
          [false, %w(early return)]
        end

        def resolve(**args)
          raise 'Should not get here'
        end
      end
    end

    it 'runs correctly in our test framework' do
      expect(resolve(resolver)).to contain_exactly('early', 'return')
    end

    it 'single selects the first early return value' do
      expect(resolve(resolver.single)).to eq('early')
    end

    it 'last selects the last early return value' do
      expect(resolve(resolver.last)).to eq('return')
    end
  end

  describe '.last' do
    it 'returns a subclass from the resolver' do
      expect(last_resolver.last.ancestors).to include(last_resolver)
    end

    it 'returns the same subclass every time' do
      expect(last_resolver.last.object_id).to eq(last_resolver.last.object_id)
    end

    it 'returns a resolver that gives the last result from the original resolver' do
      result = resolve(last_resolver.last)

      expect(result).to eq(2)
    end
  end

  context 'when field is a connection' do
    it 'increases complexity based on arguments' do
      field = Types::BaseField.new(name: 'test', type: GraphQL::STRING_TYPE.connection_type, resolver_class: described_class, null: false, max_page_size: 1)

      expect(field.to_graphql.complexity.call({}, { sort: 'foo' }, 1)).to eq 3
      expect(field.to_graphql.complexity.call({}, { search: 'foo' }, 1)).to eq 7
    end

    it 'does not increase complexity when filtering by iids' do
      field = Types::BaseField.new(name: 'test', type: GraphQL::STRING_TYPE.connection_type, resolver_class: described_class, null: false, max_page_size: 100)

      expect(field.to_graphql.complexity.call({}, { sort: 'foo' }, 1)).to eq 6
      expect(field.to_graphql.complexity.call({}, { sort: 'foo', iid: 1 }, 1)).to eq 3
      expect(field.to_graphql.complexity.call({}, { sort: 'foo', iids: [1, 2, 3] }, 1)).to eq 3
    end
  end

  describe '#object' do
    let_it_be(:user) { create(:user) }

    it 'returns object' do
      expect_next_instance_of(resolver) do |r|
        expect(r).to receive(:process).with(user)
      end

      resolve(resolver, obj: user)
    end

    context 'when object is a presenter' do
      it 'returns presented object' do
        expect_next_instance_of(resolver) do |r|
          expect(r).to receive(:process).with(user)
        end

        resolve(resolver, obj: UserPresenter.new(user))
      end
    end
  end
end
