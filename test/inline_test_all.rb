#!/usr/bin/env ruby
libdir = File.dirname(File.dirname(__FILE__)) + '/lib'
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require 'test/unit'
require 'bitformat'
require 'bitformat/inline'

class SimpleStringzInline < BitFormat::Stream
   native_endian

   stringz :str
end

class StringzInline < BitFormat::Stream
   native_endian

   uint16 :len
   stringz :str, size: :len
end

# For each test: use inline
BitFormat::Field.class_eval('@@fields').values.select do |cl|
   cl.ancestors.include?(BitFormat::Stream) && cl != BitFormat::Stream
end.each(&:inline)

class TestInlineStreams < Test::Unit::TestCase
   def test_stringz
      len = 3
      str = 'foo'
      packed_stringz = [len, str].pack('SZ*')

      stream = StringzInline.read packed_stringz

      assert_equal str, stream.str.to_s
      assert_equal 3, stream.str.size
      assert_raise EOFError do
         StringzInline.read [3, 'foo'].pack('Sa*')
      end

      simple_stream = SimpleStringzInline.read ['foo'].pack('Z*')
      assert_equal 'foo', simple_stream.str.to_s
   end

   def test_write
      packed_stringz = [3, 'foo'].pack('SZ*')
      io = StringIO.new

      assert_equal "\x03\x00foo", StringzInline.new.assign([3, 'foo']).to_s
   end
end
