module BitFormat

# Represents an integer with an arbitrary bit length.
# The number of bits is passed before field name.
#
#  class Instruction < BitFormat::Stream
#     bit 6, :opcode
#     bit 1, :direction
#     bit 1, :operand
#
#     bit 2, :mod
#     bit 3, :reg
#     bit 3, :rm
#  end
#
class Bit < Field
   include NumericField
   attr_reader :bits, :size

   # Option +bits+.
   def initialize opts={}
      super;
      @bits = opts[:bits]
      @size = (@bits.to_f / 8).ceil
      @fmt = 'C'
      @mask = (1 << @bits) - 1
   end

   # Unpacks an integer and extracts bits.
   def read str
      @value = str.unpack(@fmt).first & @mask
   end

   # Takes a readable object.
   # Returns the number of bytes consumed.
   #
   def read_io io
      @value = io.sysread(size).unpack(@fmt).first & @mask
      size
   end

   # Takes a number.
   # Returns the number of bits extracted.
   #
   def assign num
      @value = num & @mask
      @bits
   end

   def inspect
      "#@bits:#@value"
   end

   private

   def self.defined_in parent, bits, label, opts={}
      opts[:bits] = bits

      if (bit = parent.values.last).kind_of? Bit
         # append to existing bitfield
         num = parent.values.index(bit)

         parent.define_field(self, label, opts)
         this_field = parent.fields[label]

         num2 = bit.fields.size
         parent.instance_eval do
            define_method(label) {|| @values[num].fields[num2] }
         end

         parent.values.pop
         parent.labels.pop
         bit.define_field this_field
      else
         parent.define_field(BitField, label, opts)
      end
   end
end

# Created internally when two or more consecutive fields are bit-aligned.
class BitField < Bit
   attr_reader :fields

   def initialize opts={}
      super;
      @all_bits = @bits
      @fields = []
   end

   def read str
      val = str.unpack(@fmt)
      val = val.reverse_each if @endian != BIG
      val = val.inject(0) {|n, obj| (n << 8) | obj }

      @value = val & @mask
      val >>= @bits
      @fields.each {|field|
         val >>= field.assign(val)
      }
      size
   end

   def read_io io
      read io.sysread(size)
   end

   def inspect
      "#<Bit #@bits:#@value #{@fields.map(&:inspect).join(?\s)}>"
   end

   def define_field f
      @all_bits += f.bits
      @size = (@all_bits.to_f / 8).ceil
      @fields << f
      @fmt = "C#@size"
   end

   def self.by_endian opts
      if opts[:endian] == Stream::BIG
         # return memoized, modified self
         @@big_endian ||= dup.class_eval do
            alias_method :read, :read_big_endian
            public :read
            self
         end
      else
         self
      end
   end

   private

   def read_big_endian str
      val = str.unpack(@fmt).inject(0) {|n, obj| (n << 8) | obj }

      @value = val & @mask
      val >>= @bits
      @fields.each {|field|
         val >>= field.assign(val)
      }
      size
   end
end

end
