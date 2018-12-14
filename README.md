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

An empty element is marked up like `\tag<>`, but it can be abbreviated to `\tag>`.
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
If the tag name is marked with `!`, the same number of leading whitespaces as that of the least-indented line are also removed from each line.
This may be useful, if you want to insert indentations to the inner text for legibility but do not want them left in the output, for example when marking up a `<pre>` tag of XHTML. 
```
\div<
  \pre!<
    foobarbazfoobarbaz
      foobarbaz
        foobarbaz
    foobarbazfoobarbaz
  >
>
```
This will become:
```xml
<div>
  <pre>foobarbazfoobarbaz
  foobarbaz
    foobarbaz
foobarbazfoobarbaz</pre>
</div>
```

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

These options can be used simultaneously, regardless of the order of the suffixes.
```
\pre~!<
  public static void main(String... args) {
    for (int i = 0 ; i &lt> 5 ; i ++) {
      System.out.println("Hello");
    }
    System.out.println("End");
  }
>
```
This will be:
```xml
<pre>public static void main(String... args) {
  for (int i = 0 ; i &lt; 5 ; i ++) {
    System.out.println(&quot;Hello&quot;);
  }
  System.out.println(&quot;End&quot;);
}</pre>
```

### Syntactic Sugar for Multiple Elements
When consecutive elements share the same name, you can omit the name of the second and any subsequent elements, by putting `*` after the name of the first one.
```
\tag*<first><second><third>
```
This will be converted to:
```xml
<tag>first</tag><tag>second</tag><tag>third</tag>
```

If the first element, suffixed with `*`, has some attributes, the rest of the elements all have the same attributes.
```
\tag*|attr="val"|<first><second><third>
```
This will be:
```xml
<tag attr="val">first</tag><tag attr="val">second</tag><tag attr="val">third</tag>
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
In ZenML, these pseudo-attributes can be written in the same way as ordinary attributes, so the following ZenML code will be converted to the same XML as above.
```
\xml?|version="1.0",encoding="UTF-8"|>
```
Notice that there must be `,` between attribute-value pairs when you use this syntax.
Moreover, `>` is needed at the end of the element to indicate that the content is empty.

The XML declaration is not a processing instruction, but it is expressed by using this syntax.

### ZenML Declaration
ZenML documents should (but not have to) start with an ZenML declaration, as follows:
```
\zml?|version="1.0"|>
```
ZeML declarations are only used during processing, and removed in the output XML.

The version and the element name for special tags (explained below) must be declared in the pseudo-attribute style.
So `\zml?<version="1.0">` is not valid.

### Entity Reference
An entity reference begins with `&`, but ends with `>` unlike XML.
The table below shows predefined entities which can be used in ZenML documents.

| entity | character |
|:------:|:---------:|
| `&amp>` | `&` |
| `&lt>` | `>` |
| `&gt>` | `<` |
| `&apos>` | `'` |
| `&quot>` | `"` |
| `&lcub>`, `&lbrace>` | `{` |
| `&rcub>`, `&rbrace>` | `}` |
| `&lsqb>`, `&lbrack>` | `[` |
| `&rsqb>`, `&rbrack>` | `]` |
| `&sol>` | `/` |
| `&bsol>` | `\` |
| `&verbar>`, `&vert>` | `\|` |
| `&num>` | `#` |

### Special Tag
Braces (`{}`), brackets (`[]`) and slashes (`//`) are treated as a special tag in ZenML, and converted to certain elements in XML.
In the ZenML declaration, you can specify the name of tags to which these special tags are converted.
```
\zml?|version="1.0",brace="a",bracket="b",slash="c"|>
{brace} [bracket] /slash/
```
This will be:
```xml
<a>brace</a> <b>bracket</b> <c>slash</c>
```
If you do not specify the name of the special tags, they are simply not converted.
```
\zml?|version="1.0",brace="a",bracket="b"|>
{brace} [bracket] /slash/
```
This will be:
```xml
<a>brace</a> <b>bracket</b> /slash/
```

### Comment
A comment starts with `#<` and ends with `>#`.
In addition to this XML-style comment, ZenML supports a single-line comment, which is marked up by `##`.
```
\tag<foo> #<comment># \tag<bar>
## one-line comment
```
This will be converted to:
```xml
<tag>foo</tag> <!-- comment --> <tag>bar</tag>
<!-- one-line comment -->
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
# the parser uses classes offered by rexml/document library
require 'rexml/document'
include REXML
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