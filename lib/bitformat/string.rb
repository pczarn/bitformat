require 'forwardable'

module BitFormat

module StringField
   extend Forwardable
   methods = String.instance_methods - Object.instance_methods - [:size, :length, :initialize_copy]
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

   # Takes a readable object.
   # Returns the number of bytes read.
   #
   def read_io io
      @value = io.sysread(size)
      size
   end
end

class Stringz < Field
   include StringField

   # Takes a readable object.
   # Consumes bytes until and including null.
   # Returns the number of bytes read.
   #
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

class Rest < Field
   include StringField

   # Takes a readable object.
   # Consumes bytes until eof.
   # Returns the number of bytes read.
   #
   def read_io io
      @size = (@value = io.sysread).size
   end
end

end
