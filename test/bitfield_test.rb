#!/usr/bin/env ruby
libdir = File.dirname(File.dirname(__FILE__)) + '/lib'
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require 'test/unit'
require 'bitformat'
require 'bitformat/bitfield'

class NestedBits < BitFormat::Stream
   little_endian

   uint16 :len
   bit 4, :test1
   bit 4, :test2
   bit 4, :test3
   bit 4, :test4
end

class BitsBE < BitFormat::Stream
   big_endian

   uint16 :len
   bit 4, :test1
   bit 4, :test2
   bit 4, :test3
   bit 4, :test4
end

class Sib < BitFormat::Stream
   bit 2, :scale
   bit 3, :index
   bit 3, :base
end

class Instruction < BitFormat::Stream
   bit 6, :opcode
   bit 1, :direction
   bit 1, :operand

   bit 2, :mod
   bit 3, :reg
   bit 3, :rm

   sib :sib, if: -> { rm == 0b100 && mod != 0b11 }

   uint8  :displ8,  if: -> { mod == 1 }
   uint32 :displ32, if: -> { mod == 2 }
end

class WeirdInstruction < BitFormat::Stream
   bit 2, :mod
   bit 3, :reg
   bit 3, :rm

   bit 1, :reserved

   bit 2, :scale, if: -> { rm == 0b100 && mod != 0b11 }
   bit 3, :index
   bit 3, :base
end

class TestStreams < Test::Unit::TestCase
   def test_bit_read
      stream = NestedBits.read([42, 0xFF, 10].pack('SCC'))
      assert_equal 15, stream.test2
      assert_equal 10, stream.test3

      stream = BitsBE.read([42, 0xFF, 10].pack('SCC'))
      assert_equal 10, stream.test1
      assert_equal 15, stream.test3
   end

   def test_bit_if
      stream = WeirdInstruction.read([0b10000000, 0xFF, 10].pack('CCC'))
      assert_equal 3, stream.size
      assert_equal 2, stream.scale
      assert_equal 2, stream.index
   end
end
