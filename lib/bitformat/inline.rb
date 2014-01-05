require "inline"
require "bitformat"

class Module
   alias_method :inline_c, :inline
end

module BitFormat

FIXNUM_BITS = 0.size*8 - 2

C_SEP = "//----\n"

class Stream
   C_READ_INNER, C_READ_INNER_IF = <<-C.gsub(/^\s{6}/,'').split(C_SEP)
      VALUE v_%{ary} = rb_ary_new();
      %{body}
//----
      VALUE v_%{ary} = rb_ary_new();
      if(%{condition}) {
      %{body}
      }
   C

   def c_source(ary)
      (@opt_if ? C_READ_INNER_IF : C_READ_INNER) % {
         ary: ary,
         condition: case @opt_if
               when String then @opt_if
               when Proc then '1'
            end,
         body: to_h.map {|label, field|
            src = field.c_source(label)
            src += "   rb_ary_push(v_#{ary}, v_#{label});\n" if label
            src
         }.join('')
      }
   end

   def c_write_source(this_ary, str, _)
      to_h.map {|label, field|
         field.c_write_source this_ary, str, label
      }.join('')
   end

   def c_declare
      "VALUE v_#{ary};"
   end
end

module Container
   C_READ_ARY, C_READ, C_WRITE = <<-C.gsub(/^\s{6}/,'').split(C_SEP)
      VALUE read_ary(VALUE _v_str) {
         char *_str = RSTRING_PTR(_v_str);
         char *_str_end = _str + RSTRING_LEN(_v_str);
      %s
         return(v__self);
      }
//----
      VALUE read(VALUE _v_str) {
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
//----
      VALUE c_write(VALUE _self) {
         VALUE _str = rb_str_new("xxxxxxxxxxxxxxxx", 0);
      %s
         return(_str);
      }
   C

   def c_source(ary)
      new.c_source(ary)
   end

   def c_write_source(*a)
      new.c_write_source *a
   end

   def c_read_array
      C_READ_ARY % c_source('_self')
   end

   def inline(flag='-O3 -g')
      class_read_ary = C_READ_ARY % c_source('_self')
      class_read = C_READ % c_source('_self')
      method_write = C_WRITE % c_write_source('_self', '_str', nil)

      inline_c do |builder|
         builder.add_compile_flags(flag)
         builder.c_singleton(class_read_ary)
         builder.c_singleton(class_read)
         builder.c(method_write)
      end

      define_method(:to_s) do
         c_write(@values.flatten)
      end

      self
   end
end

class Array
   C_READ, C_READ_IF, C_READ_UNTIL, C_READ_UNTIL_IF, C_WRITE, C_WRITE_UNTIL =
   <<-C.gsub(/^\s{6}/,'').split(C_SEP)
      VALUE v_%{ary} = rb_ary_new();
      int i;
      for(i=0; i<%{length}; i++) {
      %{body}
         rb_ary_push(v_%{ary}, v_el_%{ary});
      }
//----
      VALUE v_%{ary} = rb_ary_new();
      if(%{condition}) {
         int i;
         for(i=0; i<%{length}; i++) {
      %{body}
            rb_ary_push(v_%{ary}, v_el_%{ary});
         }
      }
//----
      VALUE v_%{ary} = rb_ary_new();
      for(;;) {
      %{body}
         if(%{until})
            break;
         rb_ary_push(v_%{ary}, v_el_%{ary});
      }
//----
      VALUE v_%{ary} = rb_ary_new();
      if(%{condition}) {
         for(;;) {
      %{body}
            if(%{until})
               break;
            rb_ary_push(v_%{ary}, v_el_%{ary});
         }
      }
//----
      int i;
      for(i=0; i<%{length}; i++) {
      %{body}
      }
//----
      for(;;) {
      %{body}
         if(%{until})
            break;
      }
   C

   def c_source(ary_label)
      field = @type.respond_to?(:c_source) ? @type : @type.new
      if @until
         @opt_if ? C_READ_UNTIL_IF : C_READ_UNTIL
      else
         @opt_if ? C_READ_IF : C_READ
      end % {
         ary: ary_label,
         condition: @opt_if,
         length: length,
         until: case @until
            when Symbol then "el_#{ ary_label }%2 == 0"
            when Proc then "id%2 == 0"
            end,
         body: field.c_source("el_#{ ary_label }")
      }
   end

   def c_write_source(this_ary, str, label)
      (@until ? C_WRITE_UNTIL : C_WRITE) % {
         length: length,
         body: @type.new.c_write_source(this_ary, str, label),
         until: case @until
            when Symbol then "ary%2 == 0"
            when Proc then "id%2 == 0"
            end
      }
   end
end

class String
   C_READ, C_WRITE = <<-C.gsub(/^\s{6}/,'').split(C_SEP)
      char *%{label} = _str;
      if(_str+%{size} > _str_end)
         rb_raise(rb_eEOFError, "");
      VALUE v_%{label} = rb_str_new(_str, (%{size}));
      _str += (%{size});
//----
      VALUE v_%{label} = rb_ary_shift(%{ary});
      rb_str_append(%{str}, v_%{label});
   C

   def c_source(label)
      C_READ % {
         label: label,
         size: @size
      }
   end

   def c_write_source(ary, str, label)
      C_WRITE % {
         ary: ary,
         str: str,
         label: label
      }
   end
end

class Stringz
   C_READ, C_READ_IF, C_WRITE = <<-C.gsub(/^\s{6}/,'').split(C_SEP)
      VALUE v_%{label} = Qnil;
      char *%{label} = _str;
      int size_%{label} = strlen(_str);
      if(_str + size_%{label} + 1 > _str_end)
         rb_raise(rb_eEOFError, "");
      v_%{label} = rb_str_new(_str, size_%{label});
      _str += size_%{label} + 1;
//----
      VALUE v_%{label} = Qnil;
      char *%{label} = _str;
      if(%{condition}) {
         int size_%{label} = strlen(_str);
         if(_str + size_%{label} + 1 > _str_end)
            rb_raise(rb_eEOFError, "");
         v_%{label} = rb_str_new(_str, size_%{label});
         _str += size_%{label} + 1;
      }
//----
      VALUE v_%{label} = rb_ary_shift(%{ary});
      rb_str_append(%{str}, v_%{label});
   C

   def c_source(label)
      (@if ? C_READ_IF : C_READ) % {
         label: label,
         condition: @if
      }
   end

   def c_write_source(ary, str, label)
      C_WRITE % {
         ary: ary,
         str: str,
         label: label
      }
   end
end

module NumericField
   C_READ, C_READ_IF, C_WRITE, C_WRITE_IF = <<-C.gsub(/^\s{6}/,'').split(C_SEP)
      VALUE v_%{label} = Qnil;
      %{type} %{label};
      if(_str+%{size} > _str_end)
         rb_raise(rb_eEOFError, "");
      %{label} = *((%{type}*)_str);
      %{swap}
      v_%{label} = %{convert}(%{label});
      _str += (%{size});
//----
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
//----
      VALUE v_%{label} = rb_ary_shift(%{ary});
      %{type} %{label} = NUM2INT(v_%{label});
      %{swap}
      rb_str_cat(%{str}, (char*)&%{label}, %{size});
//----
      VALUE v_%{label} = rb_ary_shift(%{ary});
      %{type} %{label} = NUM2INT(v_%{label});
      %{swap}
      if(%{condition}) {
         rb_str_cat(%{str}, (char*)&%{label}, %{size});
      }
   C

   def c_source(label)
      (@opt_if ? C_READ_IF : C_READ) % {
         label: label,
         size: size,
         condition: case @opt_if
               when String then @opt_if
               when Proc then '1'
               when Symbol then '0' #%[RTEST(rb_funcall(v_self, rb_intern("#{ @opt_if }"), 0))] # call method?
            end,
         swap: @endian == NATIVE ? '' : "#{ label } = (#{ label } << 8) | (#{ label } >> 8 );",
         type: c_type,
         convert: bits > FIXNUM_BITS ? 'INT2NUM' : 'INT2FIX'
      }
   end

   def c_write_source(ary, str, label)
      (@opt_if ? C_WRITE_IF : C_WRITE) % {
         label: label,
         ary: ary,
         str: str,
         size: size,
         condition: case @opt_if
               when String then @opt_if
               when Proc then '1'
               when Symbol then %[RTEST(rb_funcall(v_#{ label }, rb_intern("#{ @opt_if }"), 0))] # call method?
            end,
         swap: @endian == NATIVE ? '' : "#{ label } = (#{ label } << 8) | (#{ label } >> 8 );",
         type: c_type,
      }
   end

   def c_declare(label)
      "#{c_type} #{label};"
   end

   def c_type
      name = self.class.field_name
      if name[-1].downcase == 'e'
         name[0 .. -2] + '_t'
      else
         name + '_t'
      end
   end
end

class BitField
   C_READ, C_READ_IF, C_WRITE, C_WRITE_IF, C_SWAP = <<-C.gsub(/^\s{6}/,'').split(C_SEP)
      if(_str+%{size} > _str_end)
         rb_raise(rb_eEOFError, "");
      typedef struct %{label}_s {
         %{type}
      } %{label}_s;
      %{label}_s %{label} = *((struct %{label}_s*)_str);
      %{body}
      _str += (%{size});
//----
      if(_str+%{size} > _str_end)
         rb_raise(rb_eEOFError, "");
      typedef struct %{label}_s {
         %{type}
      } %{label}_s;
      %{label}_s %{label} = *((struct %{label}_s*)_str);
      %{body}
      _str += (%{size});
//----
      struct {
         %{type}
      } %{label};
      %{body}
      rb_str_cat(%{str}, (char*)&%{label}, %{size});
//----
      struct {
         %{type}
      } %{label};
      if(%{condition}) {
         %{body}
         rb_str_cat(%{str}, (char*)&%{label}, %{size});
      }
//----
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

   def c_source(label)
      # TODO: condition
      (@opt_if ? C_READ_IF : C_READ) % {
         label: label,
         size: size,
         type: c_fields.join("\n"),
         body: (@endian == NATIVE ? '' : swap(label)) <<
            fields.map do |name, field|
               convert = field.bits > FIXNUM_BITS ? 'INT2NUM' : 'INT2FIX'
               "VALUE v_#{ name } = #{ convert }(#{ label }.#{ name });"
            end.join("\n")
      }
   end

   def c_write_source(ary, str, label)
      (@opt_if ? C_WRITE_IF : C_WRITE) % {
         label: label,
         str: str,
         size: size,
         condition: case @opt_if
               when Proc then '1'
               else @opt_if
            end,
         type: c_fields.join("\n"),
         body: (@endian == NATIVE ? '' : swap(label)) <<
            fields.map do |name, field|
               convert = field.bits > FIXNUM_BITS ? 'INT2NUM' : 'INT2FIX'
               "VALUE v_#{ name } = rb_ary_shift(#{ ary });\n" <<
               "#{ label }.#{ name } = #{ convert }(v_#{ name });"
            end.join("\n")
      }
   end

   def swap(label)
      C_SWAP % {
         label: label,
         size: size,
      }
   end

   def c_declare(label)
      "struct { #{ fields.map do |name, field|
         "unsigned int #{ name } : #{ field.bits };"
      end.join("\n") } } #{ label };"
   end

   def fields
      # FIXME: Order?!
      parent.to_h.to_a[@fields_offset - 1, @fields_num + 1]
   end

   def c_fields
      fields.map do |name, field|
         "unsigned int #{ name } : #{ field.bits };"
      end
   end
end

class Bit
   def c_source(label)
      ''
   end
   
   def c_write_source(ary, str, label)
      ''
   end
end

end
