#!/usr/bin/env ruby
libdir = File.dirname(File.dirname(__FILE__)) + '/lib'
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require 'test/unit'
require 'bitformat'

class ArrayStream < BitFormat::Stream
   endian NETWORK
   array :ary, type: :uint16, length: 10
end

class ArrayBlock < BitFormat::Stream
   endian LITTLE
   array :ary, length: 10 do
      uint16 :id
   end
end

class ArrayUntil < BitFormat::Stream
   endian LITTLE
   array :ary, until: -> { id.even? } do
      uint16 :id
   end
end

class ArrayUntilType < BitFormat::Stream
   endian LITTLE
   array :ary, until: :even?, type: :uint16
end

class ArrayNested < BitFormat::Stream
   endian NETWORK
   array :ary, length: 3 do
      uint16 :xy
   end

   uint16 :z
end

class TestArrays < Test::Unit::TestCase
   def test_ary
      stream = ArrayStream.new
      stream.read('xy'*10)
      assert_equal 'xy'*10, stream.to_s

      ary_block = ArrayBlock.new
      ary_block.read('xy'*10)
      assert_equal 'xy'.unpack('S').first, ary_block.ary.values.first.values.first

      ary_until = ArrayUntil.new
      ary_until.read([1, 3, 5, 7, 2, 4].pack('S*'))
      assert_equal 5, ary_until.ary.length

      ary_until = ArrayUntilType.new
      ary_until.read([1, 3, 5, 7, 2, 4].pack('S*'))
      assert_equal 5, ary_until.ary.length
   end

   def test_nested_endian
      ary_nested = ArrayNested.read([1, 2, 3, 4].pack('S*'))
      assert_equal 256, ary_nested.ary.values.first.xy
      assert_equal 1024, ary_nested.z
   end

   def test_empty
      ary_empty = BitFormat::Array.new(length: 1000)
      assert_equal 0, ary_empty.read('')
   end

   def test_copy
      s1, s2 = 'xy'*10, 'yz'*10

      # create two arrays of one class
      a_orig = ArrayBlock.read s1
      stream = ArrayBlock.read s2

      # both contain independent values
      assert_equal s1, a_orig.to_s
      assert_equal s2, stream.to_s

      # deep clone
      copy = stream.clone
      copy.read(s1)

      assert_equal s1, copy.to_s
      assert_equal s2, stream.to_s
   end
end
