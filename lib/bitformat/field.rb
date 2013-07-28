require 'set'

module BitFormat

# endian constants for DSL
NATIVE, LITTLE, BIG = *(0 .. 2)
NETWORK = BIG

class Field
   NATIVE, LITTLE, BIG = *(0 .. 2)
   NETWORK = BIG
   SIZE = nil

   attr_reader :offset, :value
   attr_accessor :size, :until, :length, :parent

   def initialize opts={}
      @endian = opts[:endian] || NATIVE
      @opt_if = opts[:if]
      @parent = opts[:parent]
	end

   # always present
   def if; true; end
   
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
	
	def self.read *str
		obj = new
      obj.read(*str)
      obj
	end
   
	def self.field_name
      name.split('::').last.gsub(/(?=[A-Z])(?<=.)/, ?_).downcase
	end

   def self.type_defined_in parent
      parent.define_type field_name, self
   end
	
   # :field_class => FieldClass
	@@fields = {}

	@@containers = Set.new

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

   def self.by_name sym
      @@fields[sym.to_sym]
   end
end

end
