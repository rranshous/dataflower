#!/usr/bin/env ruby

require 'functional'

ValuePair = Functional::Record.new(:key, :value)

State = Functional::Record.new(:value_changes, :to_handle,
                               :scratch_space, :handlers)

Functional::SpecifyProtocol(:State) do
  attr_accessor :value_changes
  attr_accessor :to_handle
  attr_accessor :scratch_space
  attr_accessor :handlers
end

class State
  def to_args
    [ self.value_changes, self.to_handle, self.scratch_space, self.handlers ]
  end
end

BLANK_STATE = State.new(value_changes: [], to_handle: [],
                        scratch_space: [], handlers: [])

class Grower
  include Functional::PatternMatching
  include Functional::Protocol
  include Functional::TypeCheck

  attr_reader :current_state

  defn(:initialize) do
    @current_state = BLANK_STATE.dup
  end

  defn(:initialize, _) do |state|
    @current_state = state
  end.when { |state| Satisfy?(state, :State) }

  defn(:next_state) do
    compute(*self.current_state.to_args)
  end

  private

  defn(:compute, [], [], [], []) do
    BLANK_STATE.dup
  end
end
