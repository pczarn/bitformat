module BitFormat

# An array that holds several fields of the same type.
class Array < Field
   attr_reader :values

   # The constant number of elements can be set with the +length+ option.
   # The +until+ option can be used to read elements until a condition is true.
   # The +type+ of an element defaults to an empty Stream class.
   # If a block is provided, it extends the type of elements.
   #
   def initialize(opts={}, &block)
      super;

      @size = nil
      @until = opts[:until]
      @length = opts[:length].kind_of?(Integer) && opts[:length]
      @type = Field.by_name(opts[:type] || :stream)

      if block_given?
         # pass endian and extend type
         @type = @type.dup
         @type.endian(@endian) if @type.respond_to? :endian
         @type.class_eval(&block)
      end

      @values =
      if @length
         ::Array.new(@length) { @type.new(endian: @endian, parent: @parent) }
      elsif @until
         []
      else
         raise ArgumentError.new('expected option `length` or `until`')
      end
   end

   def initialize_copy(_) # :nodoc:
      @values &&= @values.map(&:clone)
   end

   # Takes a string or a readable object.
   # Saves the position in bytes.
   # Returns the number of bytes read.
   #
   def read(input)
      input = StringIO.new(input) if input.kind_of? ::String
      @offset = input.pos

      if @until
         loop {
            @values << field = @type.new(endian: @endian, parent: @parent)
            field.read_io input
            break if field.send(@until)
         }
      else
         @values ||= ::Array.new(length) { @type.new(endian: @endian, parent: @parent) }
         @values.each {|field|
            field.read_io input
         }
      end

      @size = input.pos - @offset
   end

   def read_io(io)
      @offset = io.pos

      @values ||= ::Array.new(length) { @type.new(endian: @endian, parent: @parent) }
      @values.each {|field|
         field.read_io(io)
      }

      @size = io.pos - @offset
   end

   # Writes each element to a writable object.
   def write(io)
      @values.each {|el|
         el.write io
      }
   end

   # Assigns values of each field.
   def assign(ary)
      @values.zip(obj) {|field, value|
         field.assign value
      }
      self
   end

   def to_a
      @values
   end

   def to_ary
      @values
   end

   # Creates a string representation of +self+.
   def inspect
      content = ([:@length, :@until].map {|sym|
         var = instance_variable_get(sym)
         var && "#{ sym }=#{ var }"
      } << @values).compact.join(", ")
      "\#<Array #{ content }>"
   end

   private

   def self.by_endian(opts)
      case opts[:until]
      when Proc
         # return memoized, modified self
         @@until_proc ||= dup.class_eval do
            remove_method :read_io
            alias_method :read_io, :read_io_until
            public :read_io
            self
         end
      when Symbol
         @@until_sym ||= dup.class_eval do
            remove_method :read_io
            alias_method :read_io, :read_io_until_sym
            public :read_io
            self
         end
      else
         self
      end
   end

   def read_io_until(io)
      @offset = io.pos

      loop {
         @values << field = @type.new(endian: @endian, parent: @parent)
         field.read_io io
         break if field.instance_exec(&@until)
      }
      @length = @values.length
      @size = io.pos - @offset
   end

   def read_io_until_sym(io)
      @offset = io.pos

      loop {
         @values << field = @type.new(endian: @endian, parent: @parent)
         field.read_io io
         break if field.send(@until)
      }
      @length = @values.length
      @size = io.pos - @offset
   end
end

end
