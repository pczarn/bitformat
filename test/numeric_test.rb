#!/usr/bin/env ruby
libdir = File.dirname(File.dirname(__FILE__)) + '/lib'
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require 'test/unit'
require 'bitformat'

class SimpleString < BitFormat::Stream
   endian LITTLE

   uint16 :len
   string :str, size: :len
   uint16 :id
end

class NestedString < BitFormat::Stream
   little_endian

   uint16 :len, value: 1     # 3
   string :str, size: :len   # 'foo'

   stream :nested do
      little_endian
      uint16e :id             # 42
   end
end

class SimpleStringz < BitFormat::Stream
   stringz :str
end

class IfString < BitFormat::Stream
   endian LITTLE

   uint16 :len
   string :str, size: :len
   uint16 :id, if: :nothing

   def nothing
      false
   end
end

class TestNumerics < Test::Unit::TestCase
   def setup
      @packed_16 = [@uint16 = 42].pack('S')
      @packed_24 = [@uint24 = 0x123456].pack('L<')[0, 3]
   end

   def test_values
      num = BitFormat::Uint16.read(@packed_16)
      num24 = BitFormat::Uint24.read(@packed_24)

      # get values by their names
      assert_equal @uint16, num
      assert_equal @uint24, num24
   end
end
