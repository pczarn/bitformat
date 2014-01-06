require "inline"
require "bitformat"

class Module
   alias_method :inline_c, :inline
end

module BitFormat

FIXNUM_BITS = 0.size*8 - 2

C_SEP = "//----"

module Container
   def inline(flag='-O3 -std=c99')
      i = new
      i.accept(rv = ReadVisitor.new, "_self")
      i.accept(wv = WriteVisitor.new, nil, "_self")
      s_read_ary = ReadVisitor::SRC_ARY % rv.src
      s_read     = ReadVisitor::SRC % rv.src
      s_write    = WriteVisitor::SRC % wv.src

      inline_c do |builder|
         builder.add_compile_flags(flag)
         builder.c_singleton(s_read_ary)
         builder.c_singleton(s_read, :method_name => "read")
         builder.c(s_write)
      end

      define_method(:to_s) do
         c_write(@values.flatten)
      end

      self
   end
end

class Visitor
   attr_reader :src

   def initialize
      @src = ""
   end

   def self.code_set(s)
      if m = s.match(/\A.*\n/)
         const_set(m[0].strip, m.post_match)
      end
   end
end

class ReadVisitor < Visitor
   <<-C.gsub(/^\s{6}/,'').split(C_SEP).drop(1).each {|s| code_set(s) }
//---- SRC
      VALUE read_instance(VALUE _v_str) {
         if(rb_respond_to(_v_str, rb_intern("read"))) {
            _v_str = rb_funcall(_v_str, rb_intern("read"), 0);
         }
         char *_str = RSTRING_PTR(_v_str);
         char *_str_end = _str + RSTRING_LEN(_v_str);
      %s
         VALUE v_self = rb_class_new_instance(0, NULL, self);
         rb_funcall(v_self, rb_intern("assign"), 1, v__self);
         rb_funcall(v_self, rb_intern("size="), 1, INT2FIX(_str - RSTRING_PTR(_v_str)));
         return(v_self);
      }
//---- SRC_ARY
      VALUE read_ary(VALUE _v_str) {
         char *_str = RSTRING_PTR(_v_str);
         char *_str_end = _str + RSTRING_LEN(_v_str);
      %s
         return(v__self);
      }
//---- STREAM
      VALUE v_%{ary} = rb_ary_new();
//---- STREAM_IF
      VALUE v_%{ary} = rb_ary_new();
      if(%{condition}) {
         //
      }
//---- STREAM_C
      rb_ary_push(v_%{ary}, v_%{label});
//---- ARRAY
      VALUE v_%{label} = rb_ary_new();
      int i;
      for(i=0; i<%{length}; i++) {
      //
         rb_ary_push(v_%{label}, v_el_%{label});
      }
//---- ARRAY_IF
      VALUE v_%{label} = rb_ary_new();
      if(%{condition}) {
         int i;
         for(i=0; i<%{length}; i++) {
      //
            rb_ary_push(v_%{label}, v_el_%{label});
         }
      }
//---- ARRAY_UNTIL
      VALUE v_%{label} = rb_ary_new();
      for(;;) {
      //
         if(%{until})
            break;
         rb_ary_push(v_%{label}, v_el_%{label});
      }
//---- ARRAY_UNTIL_IF
      VALUE v_%{label} = rb_ary_new();
      if(%{condition}) {
         for(;;) {
      //
            if(%{until})
               break;
            rb_ary_push(v_%{label}, v_el_%{label});
         }
      }
//---- STRING
      char *%{label} = _str;
      if(_str+%{size} > _str_end)
         rb_raise(rb_eEOFError, "s");
      VALUE v_%{label} = rb_str_new(_str, (%{size}));
      _str += (%{size});
//---- STRINGZ
      VALUE v_%{label} = Qnil;
      char *%{label} = _str;
      int size_%{label} = strlen(_str);
      if(_str + size_%{label} + 1 > _str_end)
         rb_raise(rb_eEOFError, "");
      v_%{label} = rb_str_new(_str, size_%{label});
      _str += size_%{label} + 1;
//---- STRINGZ_IF
      VALUE v_%{label} = Qnil;
      char *%{label} = _str;
      if(%{condition}) {
         int size_%{label} = strlen(_str);
         if(_str + size_%{label} + 1 > _str_end)
            rb_raise(rb_eEOFError, "");
         v_%{label} = rb_str_new(_str, size_%{label});
         _str += size_%{label} + 1;
      }
//---- NUM
      VALUE v_%{label} = Qnil;
      %{type} %{label};
      if(_str+%{size} > _str_end)
         rb_raise(rb_eEOFError, "");
      %{label} = *((%{type}*)_str);
      %{swap}
      v_%{label} = %{convert}(%{label});
      _str += (%{size});
//---- NUM_IF
      VALUE v_%{label} = Qnil;
      %{type} %{label};
      %{label} = *((%{type}*)_str);
      if(%{condition}) {
         if(_str+%{size} > _str_end)
            rb_raise(rb_eEOFError, "");
         %{swap}
         v_%{label} = %{convert}(%{label});
         _str += (%{size});
      }
//---- BITFIELD
      if(_str+%{size} > _str_end)
         rb_raise(rb_eEOFError, "");
      typedef struct %{label}_s {
         %{type}
      } %{label}_s;
      %{label}_s %{label} = *((struct %{label}_s*)_str);
      %{swap}
      //
      _str += (%{size});
//---- BITFIELD_IF
      if(_str+%{size} > _str_end)
         rb_raise(rb_eEOFError, "");
      typedef struct %{label}_s {
         %{type}
      } %{label}_s;
      %{label}_s %{label} = *((struct %{label}_s*)_str);
      %{swap}
      //
      _str += (%{size});
   C

   def visit_stream(obj, h, &block)
      a, b = (h[:condition] ? STREAM_IF : STREAM).split("//\n")
      @src << a % h
      obj.each(&block)
      @src << b if b
   end

   def visit_stream_child(h)
      @src << STREAM_C % h
   end

   def visit_array(h)
      a, b = (h[:condition] ? (
         h[:until] ? ARRAY_UNTIL_IF : ARRAY_IF) : (
         h[:until] ? ARRAY_UNTIL : ARRAY)).split("//\n")
      @src << a % h
      h[:field].accept(self, "el_#{ h[:label] }", h[:label]) # FIXME: h[:ary])?
      @src << b % h
   end

   def visit_string(h)
      @src << STRING % h
   end

   def visit_stringz(h)
      @src << (h[:condition] ? STRINGZ_IF : STRINGZ) % h
   end

   def visit_numeric(h)
      @src << (h[:condition] ? NUM_IF : NUM) % h
   end

   def visit_bitfield(bits, h, &visitor)
      a, b = (h[:condition] ? BITFIELD_IF : BITFIELD).split("//\n")
      @src << a % h
      bits.each(&visitor)
      @src << b % h
   end

   def visit_bit(h)
      @src << "VALUE v_%{label} = %{convert}(%{parent_label}.%{label});\n" % h
   end
end

class WriteVisitor < Visitor
   <<-C.gsub(/^\s{6}/,'').split(C_SEP).drop(1).each {|s| code_set(s) }
//---- SRC
      VALUE c_write(VALUE _self) {
         VALUE _str = rb_str_new("", 0);
      %s
         return(_str);
      }
//---- ARRAY
      int i;
      for(i=0; i<%{length}; i++) {
      //
      }
//---- ARRAY_UNTIL
      for(;;) {
      //
         if(%{until})
            break;
      }
//---- STRING
      VALUE v_%{label} = rb_ary_shift(%{ary});
      rb_str_append(_str, v_%{label});
//---- STRINGZ
      VALUE v_%{label} = rb_ary_shift(%{ary});
      rb_str_append(_str, v_%{label});
//---- NUM
      VALUE v_%{label} = rb_ary_shift(%{ary});
      %{type} %{label} = NUM2INT(v_%{label});
      %{swap}
      rb_str_cat(_str, (char*)&%{label}, %{size});
//---- NUM_IF
      VALUE v_%{label} = rb_ary_shift(%{ary});
      %{type} %{label} = NUM2INT(v_%{label});
      %{swap}
      if(%{condition}) {
         rb_str_cat(_str, (char*)&%{label}, %{size});
      }
//---- BITFIELD
      struct {
         %{type}
      } %{label};
      %{swap}
      //
      rb_str_cat(_str, (char*)&%{label}, %{size});
//---- BITFIELD_IF
      struct {
         %{type}
      } %{label};
      if(%{condition}) {
         %{swap}
         //
         rb_str_cat(_str, (char*)&%{label}, %{size});
      }
   C

   def visit_stream(obj, _, &visitor)
      # Yay, VisitorVisitor pattern!
      obj.each(&visitor)
   end

   def visit_stream_child(_) end

   def visit_array(h)
      a, b = (h[:until] ? ARRAY_UNTIL : ARRAY).split("//\n")
      @src << a % h
      h[:field].accept(self, "el_#{ h[:ary] }", h[:ary])
      @src << b % h
   end

   def visit_string(h)
      @src << STRING % h
   end

   def visit_stringz(h)
      @src << STRINGZ % h
   end

   def visit_numeric(h)
      @src << (h[:condition] ? NUM_IF : NUM) % h
   end

   def visit_bitfield(bits, h, &visitor)
      a, b = (h[:condition] ? BITFIELD_IF : BITFIELD).split("//\n")
      @src << a % h
      bits.each(&visitor)
      @src << b % h
   end

   def visit_bit(h)
      @src << "VALUE v_%{label} = rb_ary_shift(%{ary});
%{parent_label}.%{label} = %{convert}(v_%{label});\n" % h
   end
end

class Stream
   def accept(v, label, parent_label=nil)#(this_ary, str, _)
      cond = case @opt_if
         when String then @opt_if
         when Proc then '1'
      end
      v.visit_stream(labels.zip(@values), ary: label, condition: cond) do |field_label, field|
         field.accept(v, field_label, parent_label)
         v.visit_stream_child(ary: label, label: field_label)
      end
   end
end

class Array
   def accept(v, label, parent_label)
      q = case @until
      when String then @until
      when Proc then "0"
      when Symbol then "0"
      end
      v.visit_array(
         label: label,
         ary: parent_label,
         condition: @opt_if,
         length: length,
         until: q,
         field: @type.respond_to?(:accept) ? @type : @type.new # again?
      )
   end
end

class String
   def accept(v, label, parent_label)
      v.visit_string(ary: parent_label, label: label, size: @size)
   end
end

class Stringz
   def accept(v, label, parent_label)
      v.visit_stringz(ary: parent_label, label: label, condition: @if)
   end
end

module NumericField
   def accept(v, label, parent_label)
      v.visit_numeric(
         ary: parent_label,
         label: label,
         size: size,
         condition: case @opt_if
               when String then @opt_if
               when Proc then '1'
               when Symbol then '0' # call method?
            end,
         swap: @endian == NATIVE ? '' : "#{ label } = (#{ label } << 8) | (#{ label } >> 8 );",
         type: c_type,
         convert: bits > FIXNUM_BITS ? 'INT2NUM' : 'INT2FIX')
   end

   def c_type
      self.class.field_name.sub(/[eE]\Z/,'') + "_t"
   end
end

class BitField
   C_SWAP = <<-C.gsub(/^\s{6}/,'')
      char *%{label}_str = ((char*)&%{label});
      char *end = %{label}_str + %{size} - 1;
      while(%{label}_str < end) {
         *%{label}_str ^= *end;
         *end ^= *%{label}_str;
         *%{label}_str ^= *end;
         %{label}_str++;
         end--;
      }
   C

   def accept(v, label, parent_label)
      v.visit_bitfield(
         fields,
         label: label,
         size: size,
         condition: case @opt_if
               when Proc then '1'
            end,
         type: c_fields.join("\n"),
         swap: (@endian == NATIVE ? '' : C_SWAP) % {
               label: label,
               size: size,
            }
      ) do |name, field|
         field.accept_bit(v, name, label, parent_label)
      end
   end

   def fields
      # FIXME: Order?!
      parent.labels.zip(parent.values)[@fields_offset - 1, @fields_num + 1]
   end

   def c_fields
      fields.map do |name, field|
         "unsigned int #{ name } : #{ field.bits };"
      end
   end
end

class Bit
   def accept(v, _, _) end

   def accept_bit(v, label, parent_label, ary_label)
      convert = bits > FIXNUM_BITS ? 'INT2NUM' : 'INT2FIX'
      v.visit_bit(convert: convert, label: label, parent_label: parent_label, ary: ary_label)
   end
end

end # module BitFormat
