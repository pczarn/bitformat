#!/usr/bin/env ruby
libdir = File.dirname(File.dirname(__FILE__)) + '/lib'
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require 'test/unit'
require 'bitformat'

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
