# coding: utf-8


require 'pp'
require_relative '../source/convert'

Encoding.default_external = "UTF-8"
$stdout.sync = true


source = File.read("sample.zml")
converter = ZenithalConverter.new(source)
File.open("sample.xml", "w") do |file|
  file.print(converter.convert)
end