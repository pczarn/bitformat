require 'forwardable'

module BitFormat

FIXNUM_BITS = 0.size*8 - 2

module NumericField
   extend Forwardable
   methods = Fixnum.instance_methods - Object.instance_methods
   def_delegators :@value, *methods, :eql?, :==, :<=>, :hash, :to_s
	
	def read str
      if self.if
         str = str.sysread(size) if not str.kind_of?(::String)
         @value = str.unpack(format).first
         size
      else
         0
      end
	end
   alias_method :read_io, :read
   
   def write io
      io.write [@value].pack(format)
   end

   def format; end
   
   def inspect
      "#<#{ self.class.name } #@value>"
   end
end

def self.define_numeric name, size, fmt
   fmt ||= ["a#{size}"]

   num = Class.new(Field) do
      include NumericField

      class_eval <<-RUBY
         def self.name; "#{name}"; end
         def size; #{size}; end
         def bits; #{size*8}; end
      RUBY

      if fmt.size == 3 and fmt.kind_of? ::Array
         class_eval "def format; @@FORMAT[@endian]; end"
         format = fmt
      else
         format = fmt.first
      end

      class_variable_set :@@FORMAT, format.freeze
   end

   (num_e = num.dup).class_eval <<-RUBY
      def self.name; '#{name}e'; end
      def format; @@FORMAT; end
      @@FORMAT = '#{fmt[1]}'.freeze
   RUBY

   # must hardcode field name, otherwise changed Int8E => int8_e
   (num_E = num.dup).class_eval <<-RUBY
      def self.field_name; '#{num.field_name}E'; end
      def self.name; '#{name}E'; end
      def format; @@FORMAT; end
      @@FORMAT = '#{fmt[2]}'.freeze
   RUBY

   num.define_singleton_method(:by_endian) do |opts|
      [num, num_e, num_E][opts[:endian]]
   end

   const_set name, num
   const_set :"#{name}e", num_e
   const_set :"#{name}E", num_E

   Field.register_type num
   Field.register_type num_e
   Field.register_type num_E
end

[
   'c',        # int8
   's s> s<',  # int16
   nil,
   'l l> l<',  # int32
   nil,
   nil,
   nil,
   'q q> q<',  # int64
].zip(1 .. 16).each do |fmt, size|
   if fmt
      signed_fmt = fmt.split
      unsigned_fmt = fmt.upcase.split
   end
	
   bits = size * 8

   define_numeric :"Int#{bits}", size, signed_fmt
	define_numeric :"Uint#{bits}", size, unsigned_fmt
end

define_numeric :Float, 4, %w(f e g)
define_numeric :Double, 8, %w(D E G)

end
