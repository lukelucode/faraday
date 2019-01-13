module Faraday
  # Subclasses Struct with some special helpers for converting from a Hash to
  # a Struct.
  class Options < Struct
    # Public
    def self.from(value)
      value ? new.update(value) : new
    end

    # Public
    def each
      return to_enum(:each) unless block_given?
      members.each do |key|
        yield(key.to_sym, send(key))
      end
    end

    # Public
    def update(obj)
      obj.each do |key, value|
        sub_options = self.class.options_for(key)
        if sub_options
          new_value = sub_options.from(value) if value
        elsif value.is_a?(Hash)
          new_value = value.dup
        else
          new_value = value
        end

        self.send("#{key}=", new_value) unless new_value.nil?
      end
      self
    end

    # Public
    def delete(key)
      value = send(key)
      send("#{key}=", nil)
      value
    end

    # Public
    def clear
      members.each { |member| delete(member) }
    end

    # Public
    def merge!(other)
      other.each do |key, other_value|
        self_value = self.send(key)
        sub_options = self.class.options_for(key)
        new_value = (self_value && sub_options && other_value) ? self_value.merge(other_value) : other_value
        self.send("#{key}=", new_value) unless new_value.nil?
      end
      self
    end

    # Public
    def merge(other)
      dup.merge!(other)
    end

    # Public
    def deep_dup
      self.class.from(self)
    end

    # Public
    def fetch(key, *args)
      unless symbolized_key_set.include?(key.to_sym)
        key_setter = "#{key}="
        if args.size > 0
          send(key_setter, args.first)
        elsif block_given?
          send(key_setter, Proc.new.call(key))
        else
          raise self.class.fetch_error_class, "key not found: #{key.inspect}"
        end
      end
      send(key)
    end

    # Public
    def values_at(*keys)
      keys.map { |key| send(key) }
    end

    # Public
    def keys
      members.reject { |member| send(member).nil? }
    end

    # Public
    def empty?
      keys.empty?
    end

    # Public
    def each_key
      return to_enum(:each_key) unless block_given?
      keys.each do |key|
        yield(key)
      end
    end

    # Public
    def key?(key)
      keys.include?(key)
    end

    alias has_key? key?

    # Public
    def each_value
      return to_enum(:each_value) unless block_given?
      values.each do |value|
        yield(value)
      end
    end

    # Public
    def value?(value)
      values.include?(value)
    end

    alias has_value? value?

    # Public
    def to_hash
      hash = {}
      members.each do |key|
        value = send(key)
        hash[key.to_sym] = value unless value.nil?
      end
      hash
    end

    # Internal
    def inspect
      values = []
      members.each do |member|
        value = send(member)
        values << "#{member}=#{value.inspect}" if value
      end
      values = values.empty? ? ' (empty)' : (' ' << values.join(", "))

      %(#<#{self.class}#{values}>)
    end

    # Internal
    def self.options(mapping)
      attribute_options.update(mapping)
    end

    # Internal
    def self.options_for(key)
      attribute_options[key]
    end

    # Internal
    def self.attribute_options
      @attribute_options ||= {}
    end

    def self.memoized(key)
      memoized_attributes[key.to_sym] = Proc.new
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{key}() self[:#{key}]; end
      RUBY
    end

    def self.memoized_attributes
      @memoized_attributes ||= {}
    end

    def [](key)
      key = key.to_sym
      if method = self.class.memoized_attributes[key]
        super(key) || (self[key] = instance_eval(&method))
      else
        super
      end
    end

    def symbolized_key_set
      @symbolized_key_set ||= Set.new(keys.map { |k| k.to_sym })
    end

    def self.inherited(subclass)
      super
      subclass.attribute_options.update(attribute_options)
      subclass.memoized_attributes.update(memoized_attributes)
    end

    def self.fetch_error_class
      @fetch_error_class ||= if Object.const_defined?(:KeyError)
        ::KeyError
      else
        ::IndexError
      end
    end
  end
end

require_relative 'options/request_options'
require_relative 'options/ssl_options'
require_relative 'options/proxy_options'
require_relative 'options/connection_options'
require_relative 'options/env'