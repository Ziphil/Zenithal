# coding: utf-8


require 'pp'
require 'rexml/document'
require_relative '../source/parser'
include REXML

Encoding.default_external = "UTF-8"
$stdout.sync = true


directory = File.dirname($0).encode("utf-8")
source = File.read(directory + "/sample.zml")
parser = ZenithalParser.new(source)

parser.register_macro("plus") do |attributes, children_list|
  children = children_list.first
  result = attributes["a"].to_i + attributes["b"].to_i
  result_element = Element.new("strong")
  result_element.text = "#{result}"
  next [children.first, result_element]
end

File.open(directory + "/sample.xml", "w") do |file|
  formatter = Formatters::Default.new
  document = parser.parse
  formatter.write(document, file)
end