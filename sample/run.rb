# coding: utf-8


require 'pp'
require 'rexml/document'
require_relative '../source/parser'
include REXML

Encoding.default_external = "UTF-8"
$stdout.sync = true


source = File.read("sample.zml")
parser = ZenithalParser.new(source)
File.open("sample.xml", "w") do |file|
  formatter = Formatters::Default.new
  nodes = parser.parse
  nodes.each do |node|
    formatter.write(node, file)
  end
end