require 'forwardable'

module BitFormat

module NumericField
   include Yell::Loggable
   extend Forwardable
   methods = Fixnum.instance_methods - Object.instance_methods - [:initialize_copy]
   def_delegators :@value, *methods, :hash, :to_s

   # Unpacks a numeric from a string.
   # Returns its size in bytes.
   def read(str)
      str = str.sysread(size) if not str.kind_of?(::String)
      @value = str.unpack(format).first
      size
   end
   alias_method :read_io, :read

   # Writes a packed numeric to an IO.
   def write(io)
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

   def read_endian(str)
      str = str.sysread(size) if not str.kind_of?(::String)
      @value = format(str).first
      size
   end

   def self.define_base(size, name, fmt, padding=0)
      num = Class.new(Field) do
         include NumericField

         class_eval <<-RUBY
            def self.name; "#{name}"; end
            def size; #{size}; end
            def bits; #{size*8}; end
            def format; @@FORMAT[@endian]; end
         RUBY

         if fmt.kind_of?(::Array) && fmt.size > 1
            if padding > 0
               class_eval <<-RUBY
                  def format(str)
                     str.center(#{ size + padding*2 }, ?\0).unpack(@@FORMAT[@endian])
                  end
                  undef_method :read
                  alias_method :read, :read_endian
                  public :read
               RUBY

               format_var = ['x' * padding + fmt.first, fmt.last]
               format_var.each(&:freeze)
            else
               format_var = fmt
            end
         else
            format_var = fmt.first
         end

         class_variable_set :@@FORMAT, format_var.freeze
      end

      BitFormat.const_set name, num
      Field.register_type num

      num
   end

   def self.define_endian(size, name, fmt, padding=0)
      num = define_base(size, name, fmt, padding)

      (num_e = num.dup).class_eval <<-RUBY
         class << self
            undef_method :name
         end
         def self.name; '#{ name }e'; end
         remove_method :format
         def format; @@FORMAT; end
         @@FORMAT = '#{ fmt[0] }'.freeze
      RUBY

      # must hardcode field name eg. int8E, otherwise changed Int8E => int8_e
      (num_E = num.dup).class_eval <<-RUBY
         class << self
            undef_method :name
            undef_method :field_name
         end
         def self.field_name; '#{ num.field_name }E'; end
         def self.name; '#{ name }E'; end
         remove_method :format
         def format; @@FORMAT; end
         @@FORMAT = '#{ fmt[1] }'.freeze
      RUBY

      if padding > 0
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

      BitFormat.const_set :"#{name}e", num_e
      BitFormat.const_set :"#{name}E", num_E

      Field.register_type num_e
      Field.register_type num_E
   end

   def self.define(size, name, fmt, uname, ufmt, padding=0)
      define_endian size, name, fmt, padding
      define_endian size, uname, ufmt, padding
   end
end

# int8
NumericField.define_base 1, :Int8, ['c']
NumericField.define_base 1, :Uint8, ['c']

[
   's< s>',  # int16
   'l< l>',  # int32
   'q< q>',  # int64
].each_with_index do |fmt, i|
   int_fmt, unsigned_fmt = fmt.split, fmt.upcase.split

   (2**i + 1 .. 2 * 2**i).each {|size|
      NumericField.define(
         size,
         :"Int#{size*8}", int_fmt,
         :"Uint#{size*8}", unsigned_fmt,
         2*2**i - size # padding
      )
   }
end

NumericField.define_endian 4, :Float, %w(e g)
NumericField.define_endian 8, :Double, %w(E G)

end
