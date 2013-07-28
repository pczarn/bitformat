module BitFormat

module Container
   attr_reader :endian
   
	def fields; @fields ||= {} end
   def values; @values ||= [] end
   def labels; @labels ||= [] end

   # Define a new type of field
   def define_type field_name, field_class=nil, &block
      define_singleton_method(field_name) do |*args, &extension|
         if field_class.respond_to? :defined_in
            field_class.defined_in self, *args, &extension
         else
            define_field field_class, *args, &extension
         end
      end
   end

    # Define an instance of field class
   def define_field field_class, label, opts={}, &extension
      raise "method #{self}##{label} already defined" if method_defined? label

      opts[:endian] ||= @endian
      field_class = field_class.by_endian(opts) if field_class.respond_to? :by_endian
      fields[label] = field = field_class.new(opts, &extension)

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

   def endian type
      @endian = type
   end
   
   def inherited by_class
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

class Stream < Field
   extend Container

   attr_reader :values

	def initialize opts={}, &extension
      super;

      if block_given?
         # evaluate block in context of an eigenclass after passing endianness
         this_class = singleton_class
         this_class.endian(opts[:endian] || 0)
         this_class.instance_eval &extension
      else
         this_class = self.class
         this_class.endian(opts[:endian] || 0)
      end

      # deep clone
      @values = this_class.values.map(&:clone).each {|field| field.parent = self }
   end

   def initialize_copy *_
      # :nodoc:
      @values.map!(&:clone).each {|field| field.parent = self }
   end
	
	def read input
      if not self.if
         # this stream is excluded
         return @size = 0
      end
      
      # wrap strings in stringIO
      input = StringIO.new(input) if input.kind_of? ::String

      @offset = input.pos
      @values.each {|field|
         field.read_io(input)
      }
      @size = input.pos - @offset
	end
   alias_method :read_io, :read

   def assign ary
      @values.zip(ary).each {|field, obj|
         field.assign obj
      }
      self
   end
   
   def write io
      @values.each {|field|
         field.write io
      }
   end
   
   def to_s
      io = StringIO.new
      write io
      io.string
   end
	
	def to_a
      @values.clone
	end
	
	def to_h
      Hash[self.class.labels.zip(@values)]
	end
   
   def inspect
      "#<Stream #@values>"
   end
end

end
