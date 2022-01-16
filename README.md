<div align="center">
<h1>Zenithal Markup Language (ZenML)</h1>
</div>

![](https://img.shields.io/gem/v/zenml?label=version)
![](https://img.shields.io/github/commit-activity/y/Ziphil/Zenithal?label=commits)


## Overview
Zenithal Markup Language (ZenML) serves an alternative syntax for XML.
It is almost fully compatible with XML, and less redundant and more readable than XML.

This repository provides a script for converting ZenML to XML, together with the utility classes which help to transform XML documents.

This library is obsolete and no longer maintained.
Use the [TypeScript implementation](https://github.com/Ziphil/Zenml) instead.

## Installation
Install from RubyGems.
```
gem install zenml
```

## Syntax
Note that the version of the syntax itself is independent of that of the processor.

- [Version 1.0](document/1.0.md)
- Version 1.1 (in preparation)

## Usage
Create a `ZenithalParser` instance with a ZenML string, and then call `parse` method.
This method returns a `REXML::Document` instance.
If you want an XML string instead of a syntax tree, use formatters of `rexml/document` library.

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
  document = parser.run
  formatter.write(document, file)
end
```
