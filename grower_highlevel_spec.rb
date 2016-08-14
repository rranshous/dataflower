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



end
