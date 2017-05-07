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
      # rand target_key, min, max
      rand: lambda { |(target_key, min, max), current_data, value_setter|
        value_setter.call(target_key, rand(min..max))
      },
      # diff target_key, state_data(key1), state_data(key2)
      diff: lambda { |(target_key, key1, key2), current_data, value_setter|
        value1 = current_data.find{ |vp| vp.key == key1 }
        value2 = current_data.find{ |vp| vp.key == key2 }
        value_setter.call(target_key, value1 - value2)
      },
      # set_if_lt target_key, target_value, state_data(condition_key), condition_value
      set_if_lt: lambda { |(target_key, target_value, condition_key, condition_value), current_data, value_setter|
        current_value_record = current_data.find{ |vp| vp.key == condition_key }
        current_value = current_value_record.value

        if current_value < condition_value
          value_setter.call(target_key, target_value)
        end
      },
      subtract: lambda { |(target_key, key1, key2), current_data, value_setter|
        value1 = current_data.find{ |vp| vp.key == key1 }.value
        value2 = current_data.find{ |vp| vp.key == key2 }.value
        value_setter.call(target_key, value1 - value2)
      },
      add: lambda do |(key, to_add), current_data, value_setter|
        record = current_data.find{ |vp| vp.key == key }
        puts "ADD (#{key}, #{to_add}) #{record}"
        if record.nil?
          puts "current value not found"
          current_value = 0
        else
          current_value = record.value
        end
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
  #  the seed state should always intend to have an end state

  context 'pick random numbers until you get under a given value' do
    let(:ceiling_value) { rand(10..20) }
    let(:value_changes) { [
      ValuePair.new(key: :need_random, value: 1),
    ] }
    # this solution feels unbeautiful
    # { need_random: true }
    # rand :rand_number, 0, 100, on_change_to(:need_random)
    # subtract state_data(:diff), ceiling_value, state_data(:rand_number), on_change_to(:rand_number)
    # set_if_lt :need_random, 1, state_data(:diff), 0, on_change_to(:diff)
    let(:handle_rand) {
      Handler.new(conditions: [ Condition.new(key: :need_random) ],
                  name: :rand,
                  data: [:rand_number, 0, 100])
    }
    let(:handle_subtract) {
      Handler.new(conditions: [ Condition.new(key: :rand_number) ],
                  name: :subtract,
                  data: [:diff, ceiling_value, :rand_number])
    }
    let(:handle_set_if_lt) {
      Handler.new(conditions: [ Condition.new(key: :diff) ],
                  name: :set_if_lt,
                  data: [:need_random, 1, :diff])
    }
    let(:handlers) do
      [ handle_rand, handle_subtract,  handle_set_if_lt ]
    end
    it '' do
      grower = instance
      grower_next_state = grower.next_state
      expected_next_state = set(grower.current_state, {
        value_changes: [],
        scratch_space: grower.current_state.value_changes,
        to_handle: [handle_rand]
      })
      expect(grower_next_state).to eq(expected_next_state)

      # than it runs the first handler and lines up it's value changes
      # removing the applied handler from the to_handle list
      grower = described_class.new(grower_next_state, handler_stock)
      puts "test growing: #{grower.current_state}"
      grower_next_state = grower.next_state
      expect(grower_next_state.to_handle).to eq([])
      rand_value = grower_next_state.value_changes.find{ |vp| vp.key == :rand_number }.value
      puts "RAND_VALUE: #{rand_value}"
      expect(rand_value).not_to eq nil


      grower = described_class.new(grower_next_state, handler_stock)
      puts "test growing: #{grower.current_state}"
      grower_next_state = grower.next_state
      puts "NEW STATE: #{grower_next_state}"
      expect(grower_next_state.value_changes).to eq([])
      expect(grower_next_state.to_handle).to eq([handle_subtract])
    end
  end

  context 'never ending value update scenario' do
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
    it 'adds to the value, ends up w/ the right scratch values, adds value .. etc' do
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
        to_handle: [grower.current_state.handlers.last]
      })
      expect(grower_next_state).to eq(expected_next_state)

      # than it applies the value changes
      # and lines hte handlers up again to handle
      grower = described_class.new(grower_next_state, handler_stock)
      puts "test growing: #{grower.current_state}"
      grower_next_state = grower.next_state
      expected_next_state = set(grower.current_state, {
        value_changes: [ ],
        scratch_space: [ ValuePair.new(key: :to_update, value: 1) ],
        to_handle: grower.current_state.handlers.reverse
      })
      expect(grower_next_state).to eq(expected_next_state)

      # work the first to_handle and line up the value change
      grower = described_class.new(grower_next_state, handler_stock)
      puts "test growing: #{grower.current_state}"
      grower_next_state = grower.next_state
      expected_next_state = set(grower.current_state, {
        to_handle: [grower.current_state.handlers.first],
        value_changes: [ ValuePair.new(key: :to_update, value: 3) ]
      })
      expect(grower_next_state).to eq(expected_next_state)

      # work the value changes and add the handlers again to_handle
      grower = described_class.new(grower_next_state, handler_stock)
      puts "test growing: #{grower.current_state}"
      grower_next_state = grower.next_state
      expected_next_state = set(grower.current_state, {
        value_changes: [],
        scratch_space: [ ValuePair.new(key: :to_update, value: 3) ],
        to_handle: grower.current_state.handlers
      })
      expect(grower_next_state).to eq(expected_next_state)

      # and the cycle restarts, applies the first handler, causing changes ..
      grower = described_class.new(grower_next_state, handler_stock)
      puts "test growing: #{grower.current_state}"
      grower_next_state = grower.next_state
      expected_next_state = set(grower.current_state, {
        value_changes: [ ValuePair.new(key: :to_update, value: 4) ],
        to_handle: [grower.current_state.handlers.last]
      })
      expect(grower_next_state).to eq(expected_next_state)
    end
  end

end

def set(record, updates)
  record.class.new(record.to_h.merge(updates))
end
