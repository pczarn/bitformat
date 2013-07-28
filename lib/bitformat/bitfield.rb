module Bits

class Bit < Field
   include NumericField
   attr_reader :bits, :size

   def initialize opts={}
      super;
      @bits = opts[:bits]
      @size = (@bits.to_f / 8).ceil
      @fmt = 'C'
      @mask = (1 << @bits) - 1
   end

   def read str
      @value = str.unpack(@fmt).first & @mask
   end

   def read_io io
      @value = io.sysread(size).unpack(@fmt).first & @mask
      size
   end

   def read_bits num
      @value = num & @mask
      @bits
   end

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

   def inspect
      "#@bits:#@value"
   end
end

class BitField < Bit
   attr_reader :fields

   def initialize opts={}
      super;
      @all_bits = @bits
      @fields = []
   end

   def read str
      @value = str.unpack(@fmt).first.to_i 2
   end

   def read_io io
      vals = io.sysread(size).unpack(@fmt)
      vals = vals.reverse_each if @endian != BIG
      vals = vals.inject(0) {|n, obj| (n << 8) | obj }

      @value = vals & @mask
      vals >>= @bits
      @fields.each {|field|
         vals >>= field.read_bits(vals)
      }
      size
   end

   def define_field f
      @all_bits += f.bits
      @size = (@all_bits.to_f / 8).ceil
      @fields << f
      @fmt = "C#@size"
   end

   def inspect
      "#<Bit #@bits:#@value #{@fields.map(&:inspect).join(?\s)}>"
   end
end

end
