module BitFormat

module Container
   def fields; @fields ||= {} end
   def values; @values ||= [] end
   def labels; @labels ||= [] end

   # Define a new type of field
   def define_type(field_name, field_class=nil, &block)
      define_singleton_method(field_name) do |*args, &extension|
         if field_class.respond_to? :defined_in
            field_class.defined_in self, *args, &extension
         else
            define_field field_class, *args, &extension
         end
      end
   end

   # Define an instance of field class
   def define_field(field_class, label=nil, opts={}, &extension)
      raise "method #{self}##{label} already defined" if method_defined? label

      opts[:endian] ||= @endian
      field_class = field_class.by_endian(opts) if field_class.respond_to? :by_endian
      fields[label] = field = field_class.new(opts, &extension)

      if opts[:if].kind_of?(Proc) || opts[:if].kind_of?(Symbol)
         class << field
            alias_method :read_val,    :read
            alias_method :read_io_val, :read_io
            undef_method :read
            undef_method :read_io
            alias_method :read,    :read_if
            alias_method :read_io, :read_io_if
            public(:read, :read_io)
         end
      end
      opts.each do |key, option|
         case option
         when Proc
            define_method(method_sym=:"_#{label}_#{key}", &option)
            field.define_singleton_method(key) { @parent.send(method_sym) }
         when Symbol
            field.define_singleton_method(key) { @parent.send(option) }
         end
      end

      field.assign(opts[:default]) if opts[:default]

      num = values.size
      values << field
      labels << label

      # reader method
      define_method(label) {|| @values[num] }
   end

   # Sets endian inherited by subsequent fields.
   def endian(type)
      @endian = type
   end

   def inherited(by_class)
      super;
      by_class.native_endian
   end

   def native_endian; @endian = NATIVE; end
   def little_endian; @endian = LITTLE; end
   def big_endian;    @endian = BIG;    end
   alias network_endian big_endian

   def self.extended by
      Field.register by
   end
end

# A container for serialization of variable length fields.
# 
#
class Stream < Field
   extend Container

   attr_reader :values, :labels

   # Initializes fields.
   # Optionally evaluates a block in the context of a singleton class.
   #
   def initialize(opts={}, &extension)
      super;

      if block_given?
         # evaluate block in context of an eigenclass after passing endianness
         this_class = singleton_class
         this_class.endian(opts[:endian] || NATIVE)
         this_class.instance_eval(&extension)
         # Compatibility
         @labels = this_class.labels
      else
         this_class = self.class
         this_class.endian(opts[:endian] || NATIVE)
         @labels = this_class.labels
      end

      # deep clone
      @values = this_class.values.map(&:clone).each {|field| field.parent = self }
   end

   def initialize_copy(_) # :nodoc:
      @values = @values.map(&:clone).each {|field| field.parent = self }
   end

   # Takes a string or a readable object.
   # Saves the position in bytes.
   # Returns the number of bytes read.
   #
   def read(input)
      # wrap strings in stringIO
      input = StringIO.new(input) if input.kind_of? ::String

      @offset = input.pos
      @values.each {|field|
         field.read_io(input)
      }
      @size = input.pos - @offset
   end
   alias_method :read_io, :read

   # Writes each element to a writable object.
   def write(io)
      @values.each {|field|
         field.write io
      }
   end

   # Assigns values of each field.
   def assign(ary)
      @values.zip(ary).each {|field, obj|
         field.assign obj
      }
      self
   end

   # Returns an array of labels.
   # def labels
   #    # Ruby 1.9: clone.singleton_class.labels != singleton_class.labels
   #    log self.singleton_class, self.class.labels, self.singleton_class.labels
   #    self.class.labels + self.singleton_class.labels
   # end

   # Returns a binary string that represents the contents.
   def to_s
      io = StringIO.new
      write io
      io.string
   end

   # Returns an array of fields.
   def to_a
      @values.clone
   end

   def to_ary
      @values
   end

   # Returns a hash of fields and their labels.
   def to_h
      Hash[labels.zip(@values)]
   end

   # Creates a string representation of +self+.
   def inspect
      "\#<Stream #{ to_h }>"
   end

   def pretty_print(pp)
      pp.object_address_group(self) {
         pp.breakable
         pp.pp_hash to_h
      }
   end
end

end
