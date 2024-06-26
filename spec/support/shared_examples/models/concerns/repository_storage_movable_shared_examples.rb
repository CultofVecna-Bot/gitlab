# frozen_string_literal: true

RSpec.shared_examples 'handles repository moves' do
  describe 'associations' do
    it { is_expected.to belong_to(:container) }
  end

  describe 'scopes' do
    describe '.scheduled_or_started' do
      subject { described_class.scheduled_or_started }

      let!(:initial) { create(repository_storage_factory_key, state: 1) }
      let!(:scheduled) { create(repository_storage_factory_key, state: 2) }
      let!(:started) { create(repository_storage_factory_key, state: 3) }
      let!(:finished) { create(repository_storage_factory_key, state: 4) }

      it { is_expected.to contain_exactly(scheduled, started) }
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:container) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:source_storage_name) }
    it { is_expected.to validate_presence_of(:destination_storage_name) }

    context 'source_storage_name inclusion' do
      subject { build(repository_storage_factory_key, source_storage_name: 'missing') }

      it "does not allow repository storages that don't match a label in the configuration" do
        expect(subject).not_to be_valid
        expect(subject.errors[:source_storage_name].first).to match(/is not included in the list/)
      end
    end

    context 'destination_storage_name inclusion' do
      subject { build(repository_storage_factory_key, destination_storage_name: 'missing') }

      it "does not allow repository storages that don't match a label in the configuration" do
        expect(subject).not_to be_valid
        expect(subject.errors[:destination_storage_name].first).to match(/is not included in the list/)
      end
    end

    context 'container repository read-only' do
      subject { build(repository_storage_factory_key, container: container) }

      it "does not allow the container to be read-only on create" do
        container.set_repository_read_only!

        expect(subject).not_to be_valid
        expect(subject.errors[error_key].first).to match(/is read-only/)
      end
    end
  end

  describe 'defaults' do
    context 'destination_storage_name' do
      subject { build(repository_storage_factory_key) }

      it 'can pick new storage' do
        expect(Repository).to receive(:pick_storage_shard).and_return('picked').at_least(:once)

        expect(subject.destination_storage_name).to eq('picked')
      end
    end
  end

  describe 'state transitions' do
    before do
      stub_storage_settings('test_second_storage' => {})
    end

    context 'when in the default state' do
      let!(:storage_move) { create(repository_storage_factory_key, container: container, destination_storage_name: 'test_second_storage') }

      context 'and transitions to scheduled' do
        it 'triggers the corresponding repository storage worker' do
          expect(repository_storage_worker).to receive(:perform_async).with(container.id, 'test_second_storage', storage_move.id)

          storage_move.schedule!

          expect(container).to be_repository_read_only
        end

        context 'when the transition fails' do
          before do
            allow(storage_move.container).to receive(:set_repository_read_only!).and_raise(StandardError, 'foobar')
          end

          it 'does not trigger the corresponding repository storage worker and adds an error' do
            expect(repository_storage_worker).not_to receive(:perform_async)

            storage_move.schedule!

            expect(storage_move.errors[error_key]).to include('foobar')
          end

          it 'sets the state to failed' do
            expect(storage_move).to receive(:do_fail!).and_call_original

            storage_move.schedule!

            expect(storage_move.state_name).to eq(:failed)
            expect(container).not_to be_repository_read_only
          end
        end
      end

      context 'and transitions to started' do
        it 'does not allow the transition' do
          expect { storage_move.start! }.to raise_error(StateMachines::InvalidTransition)
        end
      end
    end

    context 'when started' do
      let!(:storage_move) { create(repository_storage_factory_key, :started, container: container, destination_storage_name: 'test_second_storage') }

      context 'and transitions to replicated' do
        it 'marks the container as writable' do
          container.set_repository_read_only!

          storage_move.finish_replication!

          expect(container).not_to be_repository_read_only
        end

        it 'updates the updated_at column of the container', :aggregate_failures do
          expect { storage_move.finish_replication! }.to change { container.updated_at }

          expect(storage_move.container.updated_at).to be >= storage_move.updated_at
        end
      end

      context 'and transitions to failed' do
        it 'marks the container as writable' do
          container.set_repository_read_only!

          storage_move.do_fail!

          expect(container).not_to be_repository_read_only
        end
      end
    end

    context 'when replicated' do
      let!(:storage_move) { create(repository_storage_factory_key, :replicated, container: container, destination_storage_name: 'test_second_storage') }

      context 'and transitions to cleanup_failed' do
        it 'marks the container as writable' do
          container.set_repository_read_only!

          storage_move.do_fail!

          expect(container).not_to be_repository_read_only
        end
      end
    end
  end
end
