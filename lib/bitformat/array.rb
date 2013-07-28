#!/usr/bin/env ruby

module Bits

class Array < Field
   attr_reader :values
   
	def initialize opts={}, &block
      super;
      
      @size = nil
      @until = opts[:until]
      @length = opts[:length] if opts[:length].kind_of? Integer
      
      if opt_type = opts[:type]
         # type is provided
         @type = Field.by_name(opt_type)
      elsif block_given?
         # type is a custom stream
         @type = Class.new(Stream, &block)
         @type.endian @endian
      else
         raise ArgumentError.new('unspecified type')
      end

      @values = ::Array.new(@length) { @type.new(endian: @endian, parent: @parent) } if @length
      @values ||= [] if @until
	end
   
   def initialize_copy obj
      @values &&= @values.clone
   end
   
   def read input
      input = StringIO.new(input) if input.kind_of? ::String
      @offset = input.pos
      
      if @until
         @size = loop.inject(0) {|pos|
            @values << field = @type.new
            field.read(str[pos .. -1])

            break pos + field.size if field.instance_exec(&@until)
            pos + field.size
         }
      else
         @values ||= ::Array.new(length) { @type.new(endian: @endian, parent: @parent) }
         @values.each {|field|
            field.read_io input
         }
      end

      @size = input.pos - @offset
   end

   def read_io io
      @offset = io.pos

      @values ||= ::Array.new(length) { @type.new(endian: @endian, parent: @parent) }
      @values.each {|field|
         field.read_io(io)
      }

      @size = io.pos - @offset
   end

   def write io
      @values.each {|el|
         el.write io
      }
   end
   
   def assign obj
      @values.zip(obj) {|field, value|
         field.assign value
      }
   end
   
   def inspect
      "#<Array #{ "@length=#@length, " if @length }#{ "@until=#@until, " if @until }#@values>"
   end

   def self.by_endian opts
      case opts[:until]
      when Proc
         # return memoized, modified self
         @@until_proc ||= dup.class_eval do
            alias_method :read_io, :read_io_until
            define_method(:length) { @values.length }
            self
         end
      when Symbol
         @@until_sym ||= dup.class_eval do
            alias_method :read_io, :read_io_until_sym
            define_method(:length) { @values.length }
            self
         end
      else
         self
      end
   end

   def read_io_until io
      @offset = io.pos

      loop {
         @values << field = @type.new(endian: @endian, parent: @parent)
         field.read_io io
         break if field.instance_exec(&@until)
      }
      @length = @values.length
      @size = io.pos - @offset
   end

   def read_io_until_sym io
      @offset = io.pos

      @size = loop {
         @values << field = @type.new(endian: @endian, parent: @parent)
         field.read_io io
         break if field.send(@until)
      }
      @length = @values.length
      @size = io.pos - @offset
   end
end

end