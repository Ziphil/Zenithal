<div align="center">
<h1>Zenithal Markup Language</h1>
</div>

## Overview
Zenithal Markup Language (“ZML”, or “ZenML” for discernability) serves an alternative syntax for XML.
It is almost fully compatible with XML, and less redundant and more readable than XML.

Notice that the syntax of ZenML is currently a draft and subject to change.

This repository provides a script for converting ZenML to XML.

## Syntax (Version 1.0)

### Element
An element is marked up by an element name following `\`, and its content is surrounded by `<` and `>`:
```
\tag<This is a content of the tag>
```
This will be converted to:
```xml
<tag>This is a content of the tag</tag>
```

Attributes are surrounded by `|` and placed between a tag name and `<`.
Each attribute-value pair is represented like `attr="value"`, and separated by `,`.
```
\tag|attr="value",foo="bar"|<content>
```
This will be converted to:
```xml
<tag attr="value" foo="bar">content</tag>
```

An empty element is marked up like `\tag<>`, but it can be also represented by `\tag>`.
```
\tag> \tag|attr="value"|>
```
This will be:
```xml
<tag/> <tag attr="value"/>
```

Of course, you can place any number of elements inside another element, as is usual in XML: 
```
\tag<nested element: \child<\child<\child<foo>>>>
```

### Changing Treatment of the Inner Text
If the tag name is suffixed with `~`, the inner text is treated as a textual data without any markup.
It shows similar behaviour to CDATA sections in XML, but entity references are valid in the tag with `~`.
```
\tag~<entity: &lt; \inner|attr="val"|<foo&gt;>
```
This will become:
```xml
<tag>entity: &lt; \inner|attr=&quot;val&quot;|&lt;foo&gt;</tag>
```
Note that the inner text ends at `>`, so if you want to include `>` in the inner text, it must be escaped.

If the tag name is marked with `!`, the leading and trailing whitespaces (including newlines) of the inner text are removed.
```
\tag!<   foo bar  baz 
    >
```
This will become:
```xml
<tag>foo bar  baz</tag>
```
If the tag name is marked with `!!`, the whitespace before and after each newlines are also removed, and thus the consequent inner text is one-line.
Note that the whitespace between ordinal letters (not at the beginning or end of a line) is preserved.
```
\tag!!<   foo bar  baz
  foo bar  baz 
    >
```
This will become:
```xml
<tag>foo bar  bazfoo bar  baz</tag>
```

### Processing Instruction
The syntax for processing instructions is identical with that for ordinary tags, except that the tag name must end with `?`.
```
\xml?<version="1.0" encoding="UTF-8">
```
This will be converted to:
```xml
<?xml version="1.0" encoding="UTF-8"?>
```

The content of processing instructions are in many cases written by pseudo-attributes.
In ZenML, these pseudo-attributes can be written in the same way as ordinary attributes, so the following ZenML document will be converted to the same XML as above.
```
\xml?|version="1.0",encoding="UTF-8"|>
```
Notice that there must be `,` between attribute-value pairs when you use this syntax.
Moreover, `>` is needed at the end of the element to indicate that the content is empty.

### ZenML Declaration
ZenML documents should (but not have to) start with an ZenML declaration, as follows:
```
\zml?|version="1.0"|>
```
ZeML declarations are only used during processing, and removed in the output XML.

### Entity Reference
The syntax for entity references are the same as XML, but there are some additional predefined entities:

| entity | character |
|:------:|:---------:|
| `&lcub;`, `&lbrace;` | `{` |
| `&rcub;`, `&rbrace;` | `}` |
| `&lsqb;`, `&lbrack;` | `[` |
| `&rsqb;`, `&rbrack;` | `]` |
| `&sol;` | `/` |
| `&bsol;` | `\` |
| `&verbar;`, `&vert;` | `\|` |
| `&num;` | `#` |

### Special Tags
Braces (`{}`), brackets (`[]`) and slashes (`//`) are treated as a special tag in ZenML, and converted to certain elements in XML.
In the ZenML declaration, you can specify the name of tags to which these special tags are converted.
```
\zml?|version="1.0",brace="a",bracket="b",slash="c"|
{brace} [bracket] /slash/
```
This will be:
```xml
<a>brace</a> <b>bracket</b> <c>slash</c>
```
If you do not specify the name of the special tags, they are simply not converted.
```
\zml?|version="1.0",brace="a",bracket="b"|
{brace} [bracket] /slash/
```
This will be:
```xml
<a>brace</a> <b>bracket</b> /slash/
```

### Comment
There is no XML style comment in ZenML.
ZenML supports only line comments, which are marked up by `#`.
```
\tag<foo>  # comment
# this is a comment
```
This will be converted to:
```xml
<tag>foo</tag>  <!-- comment -->
<!-- this is a comment -->
```

### CDATA Section
In ZenML, there is no equivalent for CDATA section of XML, but you can achieve similar effect by using a tag suffixed with `~`.

### Document Type Declaration
Not yet supported.

## Usage
Create a `ZenithalParser` instance with a ZenML string, and then call `parse` method.
This method returns a `REXML::Document` instance.
If you want a XML string instead of a syntax tree, use formatters of `rexml/document` library.

The following example code converts a ZenML file to an XML file:
```ruby
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