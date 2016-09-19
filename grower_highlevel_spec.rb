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
      },
      add: lambda do |(key, to_add), current_data, value_setter|
        puts "ADD: (#{key}, #{to_add}), #{current_data}, #{value_setter}"
        current_value = current_data.find{ |vp| vp.key == key } || 0
        value_setter.call(key, current_value + to_add)
      end
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


  # priorities:
  #  1) apply value changes (which may enqueue things to handle)
  #  2) handle things
  #
  # will never update handlers, they can't be changed right now
  # scratch space will only be updated if there are value changes
  # handlers get evaluated with the most up to date data at the time that
  #  they are executed, which will always
  # handlers can but do not have to return a value change
  # handlers can fail
  # if a handler fails the cycle is considered a failure. a new state
  #  will not be created and the cycle will be retried
  # it should be possible for a handler to succeed

  context 'sipmle value update scenario' do
    # two handlers, each one will match against the same key
    # one handler adds 1 to the value of the key the other adds 2
    let(:value_changes) { [ ValuePair.new(key: :to_update, value: 0) ] }
    let(:handlers) do
      [
        Handler.new(conditions: [ Condition.new(key: :to_update) ],
                    name: :add,
                    data: [:to_update, 1]),
        Handler.new(conditions: [ Condition.new(key: :to_update) ],
                    name: :add,
                    data: [:to_update, 2])
      ]
    end
    it 'adds to the value, ends up w/ the right scratch values' do
      # first it updates the scratch space and sets up the handlers to run,
      # clearing the value changes since it's applied them

      grower = instance
      grower_next_state = grower.next_state
      expected_next_state = set(grower.current_state, {
        value_changes: [],
        scratch_space: grower.current_state.value_changes,
        to_handle: grower.current_state.handlers
      })
      expect(grower_next_state).to eq(expected_next_state)


      # than it runs the first handler and lines up it's value changes
      # removing the applied handler from the to_handle list
      grower = described_class.new(grower_next_state, handler_stock)
      puts "test growing: #{grower.current_state}"
      grower_next_state = grower.next_state
      expected_next_state = set(grower.current_state, {
        value_changes: [ ValuePair.new(key: :to_update, value: 1) ],
        to_handle: grower.current_state.handlers[1..-1]
      })
      expect(grower_next_state).to eq(expected_next_state)

      # than it applies the value changes
      grower = described_class.new(grower_next_state, handler_stock)
      puts "test growing: #{grower.current_state}"
      grower_next_state = grower.next_state
      expected_next_state = set(grower.current_state, {
        value_changes: [ ],
        scratch_space: [ ValuePair.new(key: :to_update, value: 1) ]
      })
      expect(grower_next_state).to eq(expected_next_state)

      # now it should work the other to_handle, lining up the value change
      grower = described_class.new(grower_next_state, handler_stock)
      puts "test growing: #{grower.current_state}"
      grower_next_state = grower.next_state
      expected_next_state = set(grower.current_state, {
        to_handle: [ ],
        value_changes: [ ValuePair.new(key: :to_update, value: 3) ]
      })
      expect(grower_next_state).to eq(expected_next_state)
    end
  end

end

def set(record, updates)
  record.class.new(record.to_h.merge(updates))
end
