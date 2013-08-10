require 'forwardable'

module BitFormat

FIXNUM_BITS = 0.size*8 - 2

module NumericField
   extend Forwardable
   methods = Fixnum.instance_methods - Object.instance_methods - [:initialize_copy]
   def_delegators :@value, *methods, :hash, :to_s

   # Unpacks a numeric from a string.
   # Returns its size in bytes.
   def read str
      str = str.sysread(size) if not str.kind_of?(::String)
      @value = str.unpack(format).first
      size
   end
   alias_method :read_io, :read

   # Writes a packed numeric to an IO.
   def write io
      io.write [@value].pack(format)
   end

   def ==(other)
      other = other.value if other.kind_of?(Field)
      @value == other
   end

   def eql?(other)
      other = other.value if other.kind_of?(Field)
      @value.eql? other
   end

   def <=>(other)
      @value <=> other.to_int
   end

   def inspect
      "#<#{ self.class.name } #@value>"
   end

   private

   def read_endian str
      str = str.sysread(size) if not str.kind_of?(::String)
      @value = format(str).first
      size
   end
end

define_numeric = proc do |name, size, fmt, padding=nil|
   num = Class.new(Field) do
      include NumericField

      class_eval <<-RUBY
         def self.name; "#{name}"; end
         def size; #{size}; end
         def bits; #{size*8}; end
      RUBY

      if fmt.kind_of?(::Array) && fmt.size > 1
         if padding
            class_eval <<-RUBY
               def format str; str.center(#{ size + padding*2 }, ?\0).unpack(@@FORMAT[@endian]); end
               undef_method :read
               alias_method :read, :read_endian
               public :read
            RUBY

            fmt.first.insert(0, 'x' * padding)
         else
            class_eval "def format; @@FORMAT[@endian]; end"
         end

         format_var = fmt
      else
         format_var = fmt.first
      end

      class_variable_set :@@FORMAT, format_var.freeze
   end

   const_set name, num
   Field.register_type num

   num
end

define_numeric_endian = proc do |name, size, fmt, padding=nil|
   num = define_numeric.call(name, size, fmt, padding)

   (num_e = num.dup).class_eval <<-RUBY
      class << self
         undef_method :name
      end
      def self.name; '#{name}e'; end
      remove_method :format
      def format; @@FORMAT; end
      @@FORMAT = '#{fmt[0]}'.freeze
   RUBY

   # must hardcode field name eg. int8E, otherwise changed Int8E => int8_e
   (num_E = num.dup).class_eval <<-RUBY
      class << self
         undef_method :name
         undef_method :field_name
      end
      def self.field_name; '#{num.field_name}E'; end
      def self.name; '#{name}E'; end
      remove_method :format
      def format; @@FORMAT; end
      @@FORMAT = '#{fmt[1]}'.freeze
   RUBY

   if padding
      num_e.class_eval <<-RUBY
         undef_method :format, :read
         def format str; (str << ?\0*#{padding}).unpack(@@FORMAT); end
         alias_method :read, :read_endian
         public :read
      RUBY

      num_E.class_eval <<-RUBY
         undef_method :format, :read
         def format str; (?\0*#{padding} << str).unpack(@@FORMAT); end
         alias_method :read, :read_endian
         public :read
      RUBY
   end

   num.define_singleton_method(:by_endian) do |opts|
      [num_e, num_E][opts[:endian]]
   end

   const_set :"#{name}e", num_e
   const_set :"#{name}E", num_E

   Field.register_type num_e
   Field.register_type num_E
end

# int8
define_numeric.call(:Int8, 8, ['c'])
define_numeric.call(:Uint8, 8, ['c'])

[
   's< s>',  # int16
   'l< l>',  # int32
   'q< q>',  # int64
].each_with_index do |fmt, i|
   size = 2**i + 1
   int_fmt, unsigned_fmt = fmt.split, fmt.upcase.split

   (2**i - 1).times {|j|
      pad = 2**(i+1) - size
      define_numeric_endian.call :"Int#{size*8}", size, int_fmt, pad
      define_numeric_endian.call :"Uint#{size*8}", size, unsigned_fmt, pad
      size += 1
   }

   define_numeric_endian.call :"Int#{size*8}", size, int_fmt
   define_numeric_endian.call :"Uint#{size*8}", size, unsigned_fmt
end

define_numeric_endian.call :Float, 4, %w(e g)
define_numeric_endian.call :Double, 8, %w(E G)

end
