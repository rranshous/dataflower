#!/usr/bin/env ruby

require 'functional'
require 'pry'

module Functional
  module Record
    def set(key, value)
      self.class.new(self.to_h.merge({ key.to_sym => value }))
    end
  end
end

ValuePair = Functional::Record.new(:key, :value)

State = Functional::Record.new(:value_changes, :to_handle,
                               :scratch_space, :handlers)

Handler = Functional::Record.new(:name, :data, :conditions)

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

class HandlerStock
  def initialize handler_execs
    @handler_execs = handler_execs
  end

  def exec handler, current_data
    value_changes = []
    value_setter = lambda { |k, v|
      value_changes << ValuePair.new(key: k, value: v)
    }
    handler_exec = @handler_execs[handler.name]
    raise "handler not found: #{handler}" if handler_exec.nil?
    puts "EXEC: #{[handler.data, current_data]}"
    r = @handler_execs[handler.name].call(handler.data, current_data, value_setter)
    r || []
  end
end
    #value_changes = @handler_stock.exec(active_evoke.handler, [])

BLANK_STATE = State.new(value_changes: [], to_handle: [],
                        scratch_space: [], handlers: [])

class Grower
  include Functional::PatternMatching
  include Functional::Protocol
  include Functional::TypeCheck

  attr_reader :current_state, :handler_stock

  defn(:initialize) do
    @current_state = BLANK_STATE.dup
  end

  defn(:initialize, _, _) { |state, handler_stock|
    @current_state = state
    @handler_stock = handler_stock
  }.when { |state| Satisfy?(state, :State) }

  defn(:next_state) do
    print "growing: "
    args = self.current_state.to_args
    0.upto(3).each { |i| print args[i] == [] ? "[], " : "_, " }
    puts
    compute(*args)
  end

  private

  # computing blank state is easy, it's blank state
  defn(:compute, [], [], [], []) do
    BLANK_STATE.dup
  end

  # END STATE nothing to do ?
  defn(:compute, [], [], _, _) do |scratch_space, handlers|
    s = State.new(value_changes: [], to_handle: [],
                  scratch_space: scratch_space,
                  handlers: handlers)
    puts "END STATE: #{s}"
    s
  end

  # computing from no handlers, no scratch state and value changes results
  # in the scratch state being updated
  defn(:compute, _, [], [], []) do |value_changes|
    State.new(value_changes: [], to_handle: [],
              scratch_space: value_changes, handlers: [])
  end

  # computing with no scratch, handlers without condition and value changes
  defn(:compute, _, [], [], _) do |value_changes, handlers|
    State.new(value_changes: [],
              to_handle: handlers,
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

  # computing with no scratch, value changes, to_handle and handlers conditions
  # which overlap value changes
  defn(:compute, _, _, [], _) do |value_changes, to_handle, handlers|
    value_change_keys = value_changes.map(&:key)
    matching_handlers = handlers.select do |h|
       h.conditions.map(&:key).any? { |k| value_change_keys.include? k }
    end
    State.new(value_changes: [],
              to_handle: to_handle + (matching_handlers - to_handle),
              scratch_space: value_changes,
              handlers: handlers)
  end.when do |value_changes, to_handle, handlers|
    handlers.length > 0 &&
      (value_changes.map(&:key) &
       handlers.map(&:conditions).flatten.map(&:key)).length > 0
  end

  defn(:compute, [], _, _, _) do |to_handle, scratch_space, handlers|
    value_changes = @handler_stock.exec(to_handle.first, scratch_space)
    State.new(value_changes: value_changes,
              to_handle: to_handle[1..-1],
              scratch_space: scratch_space,
              handlers: handlers)
  end

  # some scratch, updates which overlap w/ scratch, handlers which overlap w/ change
  # already some in to_handle
  defn(:compute, _, _, _, _) do |value_changes, to_handle, scratch_space, handlers|
    puts "NEW" * 10
    value_change_keys = value_changes.map(&:key)
    matching_handlers = handlers.select do |h|
       h.conditions.map(&:key).any? { |k| value_change_keys.include? k }
    end
    overlapping_keys = value_changes.map(&:key) & scratch_space.map(&:key)
    non_updated_pairs = scratch_space.select { |vp|
      !overlapping_keys.include? vp.key
    }
    new_scratch_space = value_changes + non_updated_pairs
    State.new(value_changes: [],
              to_handle: (to_handle + (matching_handlers)).uniq,
              scratch_space: new_scratch_space,
              handlers: handlers)
  end.when do |value_changes, to_handle, scratch_space, handlers|
    overlapping_keys = value_changes.map(&:key) & scratch_space.map(&:key)
    overlapping_keys.length > 0
  end

  # computing from some scratch with updates which are additions and to_handle
  defn(:compute, _, _, _, _) do |value_changes, to_handle, scratch_space, handlers|
    puts "OLD" * 10
    value_change_keys = value_changes.map(&:key)
    matching_handlers = handlers.select do |h|
       h.conditions.map(&:key).any? { |k| value_change_keys.include? k }
    end
    State.new(value_changes: [],
              to_handle: (to_handle + (matching_handlers)).uniq,
              scratch_space: scratch_space + value_changes,
              handlers: handlers)
  end.when do |value_changes, to_handle, scratch_space, handlers|
    overlapping_keys = value_changes.map(&:key) & scratch_space.map(&:key)
    value_changes.length > 0 && overlapping_keys.length == 0
  end
end

# value_changes, to_handle, scratch_space, handlers
