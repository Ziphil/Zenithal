<div align="center">
<h1>Zenithal Markup Language</h1>
</div>

## Overview
Zenithal Markup Language (“ZML”, or “ZenML” for discernability) serves an alternative syntax for XML.
It is almost fully compatible with XML, and less redundant and more readable than XML.

This repository provides a script for converting ZenML to XML, together with the utility classes which help to transform XML documents.

## Installation
Install from RubyGems.
```
gem install zenml
```

## Syntax

Note that the version of the syntax itself is independent of that of the processor.

- [Version 1.0](document/1.0.md)

## Usage
Create a `ZenithalParser` instance with a ZenML string, and then call `parse` method.
This method returns a `REXML::Document` instance.
If you want a XML string instead of a syntax tree, use formatters of `rexml/document` library.

The following example code converts a ZenML file to an XML file:
```ruby
# the parser uses classes offered by rexml/document library
require 'rexml/document'
require 'zenml'
include REXML
include Zenithal
# read a ZenML source from a file
source = File.read("sample.zml")
parser = ZenithalParser.new(source)
File.open("sample.xml", "w") do |file|
  # create a formatter to output the node tree as a string
  formatter = Formatters::Default.new
  document = parser.parse
  formatter.write(document, file)
end
```