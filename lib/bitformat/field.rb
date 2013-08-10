require 'stringio'
require 'set'

module BitFormat

# endian constants for DSL
LITTLE = 0
BIG = NETWORK = 1
NATIVE = [1].pack('S') == [1].pack('S<') ? LITTLE : BIG

class Field
   LITTLE = 0
   BIG = NETWORK = 1
   NATIVE = NATIVE

   attr_reader :offset, :value
   attr_accessor :size, :until, :length, :parent

   # Takes common options: +endian+, +parent+ and +if+.
   # Endian defaults to native.
   #
   def initialize opts={}
      @endian = opts[:endian] || NATIVE
      @opt_if = opts[:if]
      @parent = opts[:parent]
   end

   # Assigns field's value to given object.
   def assign obj
      @value = obj
   end

   def read str
      if str.kind_of? String
         read_io StringIO.new(str)
      else
         read_io str
      end
   end

   def read_io io
      @value = io.sysread(size)
      size
   end

   def write io
      io.write @value
   end

   private

   def read_if input
      if not self.if
         return @size = 0
      end

      read_val input
   end

   # Creates and returns an instance.
   # Reads data from input.
   #
   def self.read input
      obj = new
      obj.read input
      obj
   end

   # Returns the name of class as a symbol.
   #
   #  BitFormat::BitField.field_name  # => :bit_field
   #
   def self.field_name
      name.split('::').last.gsub(/(?=[A-Z])(?<=.)/, ?_).downcase
   end

   # Returns the class by its symbol. Inverse of ::field_name.
   #
   #  BitFormat::Field.by_name(:bit_field)  # => BitFormat::BitField
   #
   def self.by_name sym
      @@fields[sym.to_sym]
   end

   # :field_class => FieldClass
   @@fields = {}

   @@containers = Set.new

   def self.type_defined_in parent
      parent.define_type field_name, self
   end

   def self.inherited field_class
      register_type(field_class) if field_class.name
   end

   def self.register_type field_class
      @@fields[field_class.field_name.to_sym] = field_class
      @@containers.each {|container| field_class.type_defined_in container }
   end

   def self.register container_class
      @@containers << container_class
      @@fields.each_value {|field| field.type_defined_in container_class }
   end
end

end
