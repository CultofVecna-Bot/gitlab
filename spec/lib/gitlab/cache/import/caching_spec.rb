# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Cache::Import::Caching, :clean_gitlab_redis_cache, :clean_gitlab_redis_shared_state, feature_category: :importers do
  shared_examples 'validated redis value' do
    let(:value) { double('value', to_s: Object.new) }

    it 'raise error if value.to_s does not return a String' do
      value_as_string = value.to_s
      message = /Value '#{value_as_string}' of type '#{value_as_string.class}' for '#{value.inspect}' is not a String/

      expect { subject }.to raise_error(message)
    end
  end

  describe '.read' do
    it 'reads a value from the cache' do
      described_class.write('foo', 'bar')

      expect(described_class.read('foo')).to eq('bar')
    end

    it 'returns nil if the cache key does not exist' do
      expect(described_class.read('foo')).to be_nil
    end

    it 'refreshes the cache key if a value is present' do
      described_class.write('foo', 'bar')

      redis = double(:redis)

      expect(redis).to receive(:get).with(/foo/).and_return('bar')
      expect(redis).to receive(:expire).with(/foo/, described_class::TIMEOUT)
      expect(Gitlab::Redis::Cache).to receive(:with).exactly(4).times.and_yield(redis)

      described_class.read('foo')
    end

    it 'does not refresh the cache key if a value is empty' do
      described_class.write('foo', nil)

      redis = double(:redis)

      expect(redis).to receive(:get).with(/foo/).and_return('')
      expect(redis).not_to receive(:expire)
      expect(Gitlab::Redis::Cache).to receive(:with).twice.and_yield(redis)

      described_class.read('foo')
    end
  end

  describe '.read_integer' do
    it 'returns an Integer' do
      described_class.write('foo', '10')

      expect(described_class.read_integer('foo')).to eq(10)
    end

    it 'returns nil if no value was found' do
      expect(described_class.read_integer('foo')).to be_nil
    end
  end

  describe '.write' do
    it 'writes a value to the cache and returns the written value' do
      expect(described_class.write('foo', 10)).to eq(10)
      expect(described_class.read('foo')).to eq('10')
    end

    it_behaves_like 'validated redis value' do
      subject { described_class.write('foo', value) }
    end
  end

  describe '.increment_by' do
    it_behaves_like 'validated redis value' do
      subject { described_class.increment_by('foo', value) }
    end
  end

  describe '.increment' do
    before do
      allow(Gitlab::Redis::SharedState).to receive(:with).and_return('OK')
    end

    it 'increment a key and returns the current value' do
      expect(described_class.increment('foo')).to eq(1)

      value = Gitlab::Redis::Cache.with { |r| r.get(described_class.cache_key_for('foo')) }

      expect(value.to_i).to eq(1)
    end
  end

  describe '.set_add' do
    it 'adds a value to a set' do
      described_class.set_add('foo', 10)
      described_class.set_add('foo', 10)

      key = described_class.cache_key_for('foo')
      values = Gitlab::Redis::Cache.with { |r| r.smembers(key) }

      expect(values).to eq(['10'])
    end

    it_behaves_like 'validated redis value' do
      subject { described_class.set_add('foo', value) }
    end
  end

  describe '.set_includes?' do
    it 'returns false when the key does not exist' do
      expect(described_class.set_includes?('foo', 10)).to eq(false)
    end

    it 'returns false when the value is not present in the set' do
      described_class.set_add('foo', 10)

      expect(described_class.set_includes?('foo', 20)).to eq(false)
    end

    it 'returns true when the set includes the given value' do
      described_class.set_add('foo', 10)

      expect(described_class.set_includes?('foo', 10)).to eq(true)
    end

    it_behaves_like 'validated redis value' do
      subject { described_class.set_includes?('foo', value) }
    end
  end

  describe '.values_from_set' do
    it 'returns empty list when the set is empty' do
      expect(described_class.values_from_set('foo')).to eq([])
    end

    it 'returns the set list of values' do
      described_class.set_add('foo', 10)

      expect(described_class.values_from_set('foo')).to eq(['10'])
    end
  end

  describe '.hash_add' do
    it 'adds a value to a hash' do
      described_class.hash_add('foo', 1, 1)
      described_class.hash_add('foo', 2, 2)

      key = described_class.cache_key_for('foo')
      values = Gitlab::Redis::Cache.with { |r| r.hgetall(key) }

      expect(values).to eq({ '1' => '1', '2' => '2' })
    end

    it_behaves_like 'validated redis value' do
      subject { described_class.hash_add('foo', 1, value) }
    end
  end

  describe '.values_from_hash' do
    it 'returns empty hash when the hash is empty' do
      expect(described_class.values_from_hash('foo')).to eq({})
    end

    it 'returns the set list of values' do
      described_class.hash_add('foo', 1, 1)

      expect(described_class.values_from_hash('foo')).to eq({ '1' => '1' })
    end
  end

  describe '.write_multiple' do
    it 'sets multiple keys when key_prefix not set' do
      mapping = { 'foo' => 10, 'bar' => 20 }

      described_class.write_multiple(mapping)

      mapping.each do |key, value|
        full_key = described_class.cache_key_for(key)
        found = Gitlab::Redis::Cache.with { |r| r.get(full_key) }

        expect(found).to eq(value.to_s)
      end
    end

    it 'sets multiple keys with correct prefix' do
      mapping = { 'foo' => 10, 'bar' => 20 }

      described_class.write_multiple(mapping, key_prefix: 'pref/')

      mapping.each do |key, value|
        full_key = described_class.cache_key_for("pref/#{key}")
        found = Gitlab::Redis::Cache.with { |r| r.get(full_key) }

        expect(found).to eq(value.to_s)
      end
    end

    it_behaves_like 'validated redis value' do
      let(:mapping) { { 'foo' => value, 'bar' => value } }

      subject { described_class.write_multiple(mapping) }
    end
  end

  describe '.expire' do
    it 'sets the expiration time of a key' do
      timeout = 1.hour.to_i

      described_class.write('foo', 'bar', timeout: 2.hours.to_i)
      described_class.expire('foo', timeout)

      key = described_class.cache_key_for('foo')
      found_ttl = Gitlab::Redis::Cache.with { |r| r.ttl(key) }

      expect(found_ttl).to be <= timeout
    end
  end

  describe '.write_if_greater' do
    it_behaves_like 'validated redis value' do
      subject { described_class.write_if_greater('foo', value) }
    end
  end
end
