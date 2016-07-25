require 'rspec'
require_relative 'grower'

describe Grower do

  let(:value_changes) { [] }
  let(:to_handle) { [] }
  let(:scratch_space) { [] }
  let(:handlers) { [] }

  let(:instance) { described_class.new(State.new(value_changes: value_changes,
                                                 to_handle: to_handle,
                                                 scratch_space: scratch_space,
                                                 handlers: handlers)) }
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

  context 'initialized with a value change only' do
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
        expect(next_state.value_changes).to eq([])
        expect(next_state.scratch_space).to include(
          ValuePair.new(key: :existing, value: 0),
          ValuePair.new(key: :other_existing, value: 1),
          ValuePair.new(key: :new, value: 1)
        )
      end
    end
  end
end
