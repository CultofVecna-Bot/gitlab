# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::PostgresHllBatchDistinctCount do
  let_it_be(:error_rate) { 4.9 } # HyperLogLog is a probabilistic algorithm, which provides estimated data, with given error margin
  let_it_be(:fallback) { ::Gitlab::Database::BatchCounter::FALLBACK }
  let_it_be(:small_batch_size) { calculate_batch_size(::Gitlab::Database::BatchCounter::MIN_REQUIRED_BATCH_SIZE) }
  let(:model) { Issue }
  let(:column) { :author_id }

  let(:in_transaction) { false }

  let_it_be(:user) { create(:user, email: 'email1@domain.com') }
  let_it_be(:another_user) { create(:user, email: 'email2@domain.com') }

  def calculate_batch_size(batch_size)
    zero_offset_modifier = -1

    batch_size + zero_offset_modifier
  end

  before do
    allow(ActiveRecord::Base.connection).to receive(:transaction_open?).and_return(in_transaction)
  end

  context 'different distribution of relation records' do
    [10, 100, 100_000].each do |spread|
      context "records are spread within #{spread}" do
        before do
          ids = (1..spread).to_a.sample(10)
          create_list(:issue, 10).each_with_index do |issue, i|
            issue.id = ids[i]
          end
        end

        it 'counts table' do
          expect(described_class.batch_distinct_count(model)).to be_within(error_rate).percent_of(10)
        end
      end
    end
  end

  context 'unit test for different counting parameters' do
    before_all do
      create_list(:issue, 3, author: user)
      create_list(:issue, 2, author: another_user)
    end

    shared_examples 'disallowed configurations' do |method|
      it 'returns fallback if start is bigger than finish' do
        expect(described_class.public_send(method, *args, start: 1, finish: 0)).to eq(fallback)
      end

      it 'returns fallback if loops more than allowed' do
        large_finish = Gitlab::Database::PostgresHllBatchDistinctCounter::MAX_ALLOWED_LOOPS * default_batch_size + 1
        expect(described_class.public_send(method, *args, start: 1, finish: large_finish)).to eq(fallback)
      end

      it 'returns fallback if batch size is less than min required' do
        expect(described_class.public_send(method, *args, batch_size: small_batch_size)).to eq(fallback)
      end
    end

    shared_examples 'when a transaction is open' do
      let(:in_transaction) { true }

      it 'raises an error' do
        expect { subject }.to raise_error('BatchCount can not be run inside a transaction')
      end
    end

    shared_examples 'when batch fetch query is canceled' do
      let(:batch_size) { 22_000 }

      it 'reduces batch size by half and retry fetch' do
        allow(model).to receive(:where).with("id" => 0..calculate_batch_size(batch_size)).and_raise(ActiveRecord::QueryCanceled)

        expect(model).to receive(:where).with("id" => 0..calculate_batch_size(batch_size / 2)).and_call_original

        subject.call(model, column, batch_size: batch_size, start: 0)
      end
    end

    describe '#batch_distinct_count' do
      it 'counts table' do
        expect(described_class.batch_distinct_count(model)).to be_within(error_rate).percent_of(5)
      end

      it 'counts with column field' do
        expect(described_class.batch_distinct_count(model, column)).to be_within(error_rate).percent_of(2)
      end

      it 'counts with :id field' do
        expect(described_class.batch_distinct_count(model, :id)).to be_within(error_rate).percent_of(5)
      end

      it 'counts with "id" field' do
        expect(described_class.batch_distinct_count(model, "id")).to be_within(error_rate).percent_of(5)
      end

      it 'counts with table.column field' do
        expect(described_class.batch_distinct_count(model, "#{model.table_name}.#{column}")).to be_within(error_rate).percent_of(2)
      end

      it 'counts with Arel column' do
        expect(described_class.batch_distinct_count(model, model.arel_table[column])).to be_within(error_rate).percent_of(2)
      end

      it 'counts over joined relations' do
        expect(described_class.batch_distinct_count(model.joins(:author), "users.email")).to be_within(error_rate).percent_of(2)
      end

      it 'counts with :column field with batch_size of 50K' do
        expect(described_class.batch_distinct_count(model, column, batch_size: 50_000)).to be_within(error_rate).percent_of(2)
      end

      it 'will not count table with a batch size less than allowed' do
        expect(described_class.batch_distinct_count(model, column, batch_size: small_batch_size)).to eq(fallback)
      end

      it 'counts with different number of batches and aggregates total result' do
        stub_const('Gitlab::Database::PostgresHllBatchDistinctCounter::MIN_REQUIRED_BATCH_SIZE', 0)

        [1, 2, 4, 5, 6].each { |i| expect(described_class.batch_distinct_count(model, batch_size: i)).to be_within(error_rate).percent_of(5) }
      end

      it 'counts with a start and finish' do
        expect(described_class.batch_distinct_count(model, column, start: model.minimum(:id), finish: model.maximum(:id))).to be_within(error_rate).percent_of(2)
      end

      it "defaults the batch size to #{Gitlab::Database::PostgresHllBatchDistinctCounter::DEFAULT_BATCH_SIZE}" do
        min_id = model.minimum(:id)
        batch_end_id = min_id + calculate_batch_size(Gitlab::Database::PostgresHllBatchDistinctCounter::DEFAULT_BATCH_SIZE)

        expect(model).to receive(:where).with("id" => min_id..batch_end_id).and_call_original

        described_class.batch_distinct_count(model)
      end

      it_behaves_like 'when a transaction is open' do
        subject { described_class.batch_distinct_count(model, column) }
      end

      context 'disallowed configurations' do
        include_examples 'disallowed configurations', :batch_distinct_count do
          let(:args) { [model, column] }
          let(:default_batch_size) { Gitlab::Database::PostgresHllBatchDistinctCounter::DEFAULT_BATCH_SIZE }
        end
      end

      it_behaves_like 'when batch fetch query is canceled' do
        let(:mode) { :distinct }
        let(:operation) { :count }
        let(:operation_args) { nil }
        let(:column) { nil }

        subject { described_class.method(:batch_distinct_count) }
      end
    end
  end
end
