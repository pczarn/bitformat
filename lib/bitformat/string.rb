#!/usr/bin/env ruby

module Bits

module StringField
   extend Forwardable
   methods = String.instance_methods - Object.instance_methods - [:size, :length]
   def_delegators :@value, *methods, :eql?, :==, :hash, :to_s, :<=>

   def inspect
      "#<String \"#@value\">"
   end
end

class String < Field
	include StringField

   def initialize opts={}
      @match = opts[:match] if opts[:match]
      super;
   end
   
   def read_io io
      if self.if
         @value = io.sysread(size)
         size
      else
         0
      end
   end
end

class Stringz < Field
	include StringField

   def read_io io
      @value = io.readline(?\0)
      # removes last character and fails if it wasn't null
      raise EOFError if @value.slice!(-1) != ?\0
      @size = @value.size + 1
   end
   
   def assign obj
      @value = obj
      @size = @value && @value.size + 1
   end
end

class Utf8 < Field
	include StringField
	
	def format; "a#@size"; end
	
	def unpack str
		str.force_encoding('UTF-8')
	end
   
   def read str
      str[0, size]
   end
end

class Rest < Field
   include StringField
   
   def read_io io
      @size = (@value = io.sysread).size
   end
end

end