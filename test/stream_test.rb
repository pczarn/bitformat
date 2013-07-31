#!/usr/bin/env ruby
libdir = File.dirname(File.dirname(__FILE__)) + '/lib'
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require 'test/unit'
require 'bitformat'

class SimpleString < BitFormat::Stream
   endian NETWORK

   uint16 :len
   string :str, size: :len
   uint16 :id
end

class NestedString < BitFormat::Stream
   network_endian

   uint16 :len, value: 1     # 3
   string :str, size: :len   # 'foo'

   stream :nested do
      little_endian
      uint16E :id             # 42
   end
end

class SimpleStringz < BitFormat::Stream
   stringz :str
end

class IfString < BitFormat::Stream
   endian NETWORK

   uint16 :len
   string :str, size: :len
   uint16 :id, if: :nothing

   def nothing
      false
   end
end

class TestStreams < Test::Unit::TestCase
   def setup
      @packed =
         (@values =
            [@len_val = 3,
             @str_val = 'foo',
             @id_val  = 42
            ]).pack('Sa*S')

      @packed2 = [3, 'bar', 123].pack('Sa*S')

      @packed_stringz = [@str_val].pack('Z*')

      @if_string = [3, 'foo'].pack('Sa*')
   end

   def test_values
      stream = SimpleString.read @packed
      stream2 = SimpleString.read @packed2

      # get values by their names
      assert_equal @len_val, stream.len
      assert_equal @str_val, stream.str
      assert_equal @id_val, stream.id
      assert_equal @packed.size, stream.size

      # access with to_a and to_h
      assert_equal [:len, :str, :id], stream.to_h.keys
      assert_equal @values, stream.to_a

      assert_equal 'bar', stream2.str
   end

   def test_io
      # write packed data to the IO
      io = StringIO.new
      io.write @packed
      io.rewind

      # read data from IO to SimpleString
      stream = SimpleString.read io

      # check values
      assert_equal @len_val, stream.len
      assert_equal @str_val, stream.str
      assert_equal @packed.size, stream.size
      assert_equal @packed, stream.to_s

      # write stream to IO
      stream.write(io = StringIO.new)

      # check written data
      assert_equal @packed, io.string
   end

   def test_stringz
      stream = SimpleStringz.read @packed_stringz

      # get contents of stringz
      assert_equal @str_val, stream.str
      assert_equal @packed_stringz.size, stream.str.size

      # fail when given an unterminated stringz
      assert_raise EOFError do
         SimpleStringz.read 'foo'
      end
   end

   def test_nested
      stream = NestedString.read @packed

      assert_equal @id_val, stream.nested.id
      assert_instance_of BitFormat::Stream, stream.nested
   end

   def test_if
      stream = IfString.read @if_string

      assert_equal @if_string.size, stream.size
      assert_equal stream.id, nil

      # redefine a method
      def stream.nothing; true; end

      assert_raise EOFError do
         stream.read @if_string
      end
   end

   def test_copy
      # create two streams of one class
      s_orig = NestedString.read @packed
      stream = NestedString.read @packed2

      # both contain independent values
      assert_equal @str_val, s_orig.str
      assert_equal @id_val, s_orig.nested.id
      assert_equal 123,     stream.nested.id

      # deep clone
      copy = stream.clone
      copy.read(@packed)

      assert_equal @id_val, copy.nested.id
      assert_equal 123, stream.nested.id
   end
end
