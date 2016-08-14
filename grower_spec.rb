require 'rspec'
require_relative 'grower'

describe Grower do

  let(:value_changes) { [] }
  let(:to_handle) { [] }
  let(:scratch_space) { [] }
  let(:handlers) { [] }
  let(:random_key) { rand(1000) }
  let(:random_value) { rand(1000) }
  let(:handler_stock) {
    HandlerStock.new({
      noop: lambda { |init_data, current_data, value_setter| },
      set_random: lambda { |init_data, current_data, value_setter|
        value_setter.call(random_key, random_value)
      }
    })
  }

  let(:instance) {
    described_class.new(
      State.new(value_changes: value_changes,
                to_handle: to_handle,
                scratch_space: scratch_space,
                handlers: handlers),
      handler_stock)
  }
  let(:current_state) { instance.current_state }
  let(:next_state) { instance.next_state }

  context 'blank initialization' do
    let(:instance) { described_class.new() }

    it 'has state of all empty arrays' do
      expect(current_state).to eq(State.new(value_changes: [], to_handle: [],
                                            scratch_space: [], handlers: []))
    end
    it 'returns all empty arrays as result of grow' do
      expect(next_state).to eq(State.new(value_changes: [], to_handle: [],
                                         scratch_space: [], handlers: []))
    end
  end

  context 'initialized with a value change' do
    let(:value_changes) { [ ValuePair.new(key: 1, value: 1) ] }

    it 'has state which inclues value changes' do
      expect(current_state).to eq(State.new(value_changes: value_changes,
                                            to_handle: [], scratch_space: [],
                                            handlers: []))
    end
    it 'has next state which scratch space has new value pair' do
      expect(next_state).to eq(State.new(value_changes: [], to_handle: [],
                                         scratch_space: value_changes,
                                         handlers: []))
    end

  end

  context 'has scratch data' do
    let(:scratch_space) { [ValuePair.new(key: :existing, value: 1)] }

    context 'adding new value pair' do
      let(:value_changes) { [ ValuePair.new(key: :added, value: 1) ] }
      it 'has next state which includes both value pairs in scratch space' do
        expect(next_state).to eq(
          State.new(value_changes: [], to_handle: [],
                    scratch_space: scratch_space + value_changes,
                    handlers: [])
        )
      end
    end

    context 'updating value pair in scratch space' do
      let(:value_changes) { [ ValuePair.new(key: :existing, value: 0) ] }
      it 'has next state which has only the new pair in the scratch space' do
        expect(next_state).to eq(
          State.new(value_changes: [], to_handle: [],
                    scratch_space: value_changes,
                    handlers: [])
        )
      end
    end

    context 'updating and adding value pair' do
      let(:scratch_space) { [ ValuePair.new(key: :existing, value: 1),
                              ValuePair.new(key: :other_existing, value: 1)] }
      let(:value_changes) { [ ValuePair.new(key: :existing, value: 0),
                              ValuePair.new(key: :new, value: 1) ] }
      it 'has next state which has new value for overlapping pair
          and new k/v and existing non-updated in scratch space' do
        expect(next_state.scratch_space).to include(
          ValuePair.new(key: :existing, value: 0),
          ValuePair.new(key: :other_existing, value: 1),
          ValuePair.new(key: :new, value: 1)
        )
      end
      it 'has next state which does not have value changes' do
        expect(next_state.value_changes).to eq([])
      end

      context 'with things to handle' do
        let(:to_handle) { [ :blah ] }
        let(:handlers) { [ :blah ] }
        it 'applies value changes as though there were not things to handle' do
          expect(next_state.scratch_space).to include(
            ValuePair.new(key: :existing, value: 0),
            ValuePair.new(key: :other_existing, value: 1),
            ValuePair.new(key: :new, value: 1)
          )
          expect(next_state.to_handle).to eq to_handle
        end
      end
    end
  end

  # we apply the value changes and set up the handler evokes in one step
  context 'has handlers with no conditions' do
    let(:handlers) {[
      Handler.new(name: :test_handler, data: {}, conditions: []),
      Handler.new(name: :test_handler2, data: {}, conditions: [])
    ]}
    context 'has value changes' do
      let(:value_changes) { [ ValuePair.new(key: :new, value: 1) ] }
      it 'has next state which includes handler evocations' do
        expect(next_state.to_handle).to eq(handlers)
      end
      it 'has next state which has no value changes' do
        expect(next_state.value_changes).to eq []
      end
      it 'has next state which has updated scratch space to value changes' do
        expect(next_state.scratch_space).to eq value_changes
      end
      it 'has next state which maintained handlers' do
        expect(next_state.handlers).to eq handlers
      end
    end
  end

  context 'has handlers with a condition' do
    let(:handler_conditions) {[ Condition.new(key: :to_watch) ]}
    let(:handlers) {[
      Handler.new(name: :set_random, data: {}, conditions: handler_conditions),
    ]}
    context 'has value changes which does not overlap with condition' do
      let(:value_changes) { [ ValuePair.new(key: :not_watched, value: 1) ] }
      # to_handle should be empty, # TODO? make explicit
      it 'has next state which maintains to_handle' do
        expect(next_state.to_handle).to eq to_handle
      end
      it 'has next state which has cleared value_changes' do
        expect(next_state.value_changes).to eq []
      end
      it 'has next state which has updated scratch space from value changes' do
        expect(next_state.scratch_space).to eq value_changes
      end
      it 'has next state which maintained handlers' do
        expect(next_state.handlers).to eq handlers
      end
    end

    context 'has value changes which overlap with one of many handlers' do
      let(:matching_handler) {
        Handler.new(name: :set_random, data: {}, conditions: handler_conditions)
      }
      let(:non_matching_handler) {
        Handler.new(name: :set_random, data: {},
                    conditions: [ Condition.new(key: :not_watched) ])
      }
      let(:handlers) {[ matching_handler, non_matching_handler ].shuffle}
      let(:value_changes) { [ ValuePair.new(key: :to_watch, value: 1) ] }
      it 'has next state which includes handler evocations only
          for handler with met conditions' do
        expect(next_state.to_handle).to eq([matching_handler])
      end
      it 'has next state which clears value changes' do
        expect(next_state.value_changes).to eq []
      end
      it 'has next state which updates its scratch space w/ value changes' do
        expect(next_state.scratch_space).to eq value_changes
      end
      it 'has next state which maintained handlers' do
        expect(next_state.handlers).to eq handlers
      end
    end

    context 'has things to handle and value changes' do
      let(:value_changes) { [ValuePair.new(key: :to_watch, value: random_value)] }
      let(:to_handle) {[
        Handler.new(name: :noop, data: {},
                    conditions: handler_conditions),
        Handler.new(name: :noop, data: {},
                    conditions: handler_conditions)
      ]}
      let(:handlers) { to_handle }
      describe '#compute' do
        it 'applies value changes' do
          expect(next_state.value_changes).to eq([])
          expect(next_state.scratch_space).to eq(value_changes)
          expect(next_state.to_handle).to eq(to_handle)
        end
      end
    end

    context 'has multiple things to_handle no existing value changes' do
      let(:value_changes) { [] }
      context 'no value changes returned by evoke' do
        let(:to_handle) {[
          Handler.new(name: :noop, data: {},
                      conditions: handler_conditions),
          Handler.new(name: :noop, data: {},
                      conditions: handler_conditions)
        ]}
        describe '#compute' do
          it 'has removed first item in to_handle' do
            expect(next_state.to_handle).to eq to_handle[1..-1]
          end
          it 'has no value_changes' do
            expect(next_state.value_changes).to eq value_changes
          end
          it 'maintained scratch space' do
            expect(next_state.scratch_space).to eq scratch_space
          end
          it 'has next state which maintained handlers' do
            expect(next_state.handlers).to eq handlers
          end
        end
        context 'first evocation returns value changes' do
          let(:evoke_with_changes) do
            Handler.new(name: :set_random, data: {}, conditions: handler_conditions)
          end
          let(:evoke_without_changes) do
            Handler.new(name: :noop, data: {}, conditions: handler_conditions)
          end
          let(:to_handle) { [evoke_with_changes, evoke_without_changes] }
          it 'has removed first item in to_handle' do
            expect(next_state.to_handle).to eq to_handle[1..-1]
          end
          it 'value changes equal those returned by evoking first to_handle' do
            expect(next_state.value_changes).to eq(
              [ValuePair.new(key: random_key, value: random_value)])
          end
          it 'maintained scratch space' do
            expect(next_state.scratch_space).to eq scratch_space
          end
          it 'has next state which maintained handlers' do
            expect(next_state.handlers).to eq handlers
          end
        end
      end
    end
  end
end
