#!/usr/bin/env ruby

require 'functional'
require 'pry'

ValuePair = Functional::Record.new(:key, :value)

State = Functional::Record.new(:value_changes, :to_handle,
                               :scratch_space, :handlers)

Handler = Functional::Record.new(:name, :data, :conditions)

Evocation = Functional::Record.new(:handler, :data)

Condition = Functional::Record.new(:key)

Functional::SpecifyProtocol(:State) do
  attr_reader :value_changes
  attr_reader :to_handle
  attr_reader :scratch_space
  attr_reader :handlers
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

  defn(:initialize, _) { |state|
    @current_state = state
  }.when { |state| Satisfy?(state, :State) }

  defn(:next_state) do
    compute(*self.current_state.to_args)
  end

  private

  # computing blank state is easy, it's blank state
  defn(:compute, [], [], [], []) do
    BLANK_STATE.dup
  end

  # computing from no handlers, no scratch state and value changes results
  # in the scratch state being updated
  defn(:compute, _, [], [], []) do |value_changes|
    State.new(value_changes: [], to_handle: [],
              scratch_space: value_changes, handlers: [])
  end

  # computing from no handlers, all existing scratch state being updated
  defn(:compute, _, [], _, []) do |value_changes, scratch_space|
    State.new(value_changes: [], to_handle: [],
              scratch_space: value_changes, handlers: [])
  end.when do |value_changes, scratch_space|
    overlapping_keys = value_changes.map(&:key) & scratch_space.map(&:key)
    overlapping_keys.length == scratch_space.length
  end

  # computing from no handlers, some existing scratch state being updated
  defn(:compute, _, [], _, []) do |value_changes, scratch_space|
    overlapping_keys = value_changes.map(&:key) & scratch_space.map(&:key)
    non_updated_pairs = scratch_space.select { |vp|
      !overlapping_keys.include? vp.key
    }
    new_scratch_space = value_changes + non_updated_pairs

    State.new(value_changes: [], to_handle: [],
              scratch_space: new_scratch_space,
              handlers: [])
  end.when do |value_changes, scratch_space|
    overlapping_keys = value_changes.map(&:key) & scratch_space.map(&:key)
    overlapping_keys.length > 0
  end

  # computing from no handlers, existing scratch state and value changes
  defn(:compute, _, [], _, []) do |value_changes, scratch_space|
    State.new(value_changes: [], to_handle: [],
              scratch_space: scratch_space + value_changes, handlers: [])
  end

  # computing with no scratch, handlers without condition and value changes
  defn(:compute, _, [], [], _) do |value_changes, handlers|
    State.new(value_changes: [],
              to_handle: handlers.map { |h|
                Evocation.new(handler: h, data: value_changes.dup) },
              scratch_space: value_changes.dup,
              handlers: handlers)
  end.when do |value_changes, handlers|
    handlers.map(&:conditions).flatten == []
  end

  # computing with no scratch, value changes, handlers conditions
  # but no overlap with changes
  defn(:compute, _, [], [], _) do |value_changes, handlers|
    State.new(value_changes: [],
              to_handle: [ ],
              scratch_space: value_changes,
              handlers: handlers)
  end.when do |value_changes, handlers|
    handlers.length > 0 &&
      (value_changes.map(&:key) &
       handlers.map(&:conditions).flatten.map(&:key)).length == 0
  end

  # computing with no scratch, value changes, handlers conditions
  # which overlap changes
  defn(:compute, _, [], [], _) do |value_changes, handlers|
    value_change_keys = value_changes.map(&:key)
    matching_handlers = handlers.select do |h|
       h.conditions.map(&:key).any? { |k| value_change_keys.include? k }
    end
    State.new(value_changes: [],
              to_handle: matching_handlers.map { |h|
                Evocation.new(handler: h, data: value_changes.dup) },
              scratch_space: value_changes,
              handlers: handlers)
  end.when do |value_changes, handlers|
    handlers.length > 0 &&
      (value_changes.map(&:key) &
       handlers.map(&:conditions).flatten.map(&:key)).length > 0
  end

  defn(:compute, [], _, [], _) do |to_handle, handlers|
    State.new(value_changes: [],
              to_handle: to_handle[1..-1],
              scratch_space: [],
              handlers: handlers)
  end
end

# value_changes, to_handle, scratch_space, handlers
