# coding: utf-8


require 'pp'
require 'rexml/document'
require_relative 'parser_utility'
include REXML


class ZenithalNewParser

  include ParserBuilder

  ELEMENT_START = "\\"
  MACRO_START = "&"
  ESCAPE_START = "`"
  ATTRIBUTE_START = "|"
  ATTRIBUTE_END = "|"
  ATTRIBUTE_EQUAL = "="
  ATTRIBUTE_VALUE_START = "\""
  ATTRIBUTE_VALUE_END = "\""
  ATTRIBUTE_SEPARATOR = ","
  CONTENT_START = "<"
  CONTENT_END = ">"
  SPECIAL_ELEMENT_STARTS = {:brace => "{", :bracket => "[", :slash => "/"}
  SPECIAL_ELEMENT_ENDS = {:brace => "}", :bracket => "]", :slash => "/"}
  COMMENT_DELIMITER = "#"
  SYSTEM_INSTRUCTION_NAME = "zml"
  MARKS = {:instruction => "?", :trim => "*", :verbal => "~", :multiple => "+"}
  ESCAPE_CHARS = ["&", "<", ">", "'", "\"", "{", "}", "[", "]", "/", "\\", "|", "`", "#"]
  SPACE_CHARS = [0x20, 0x9, 0xD, 0xA]
  VALID_FIRST_IDENTIFIER_CHARS = [
    0x3A, 0x5F,
    0x41..0x5A, 0x61..0x7A, 0xC0..0xD6, 0xD8..0xF6, 0xF8..0x2FF,
    0x370..0x37D, 0x37F..0x1FFF,
    0x200C..0x200D, 0x2070..0x218F, 0x2C00..0x2FEF,
    0x3001..0xD7FF, 0xF900..0xFDCF, 0xFDF0..0xFFFD, 0x10000..0xEFFFF
  ]
  VALID_MIDDLE_IDENTIFIER_CHARS = [
    0x2D, 0x2E, 0x3A, 0x5F, 0xB7, 
    0x30..0x39,
    0x41..0x5A, 0x61..0x7A, 0xC0..0xD6, 0xD8..0xF6, 0xF8..0x2FF,
    0x300..0x36F,
    0x370..0x37D, 0x37F..0x1FFF,
    0x200C..0x200D, 0x2070..0x218F, 0x2C00..0x2FEF,
    0x203F..0x2040,
    0x3001..0xD7FF, 0xF900..0xFDCF, 0xFDF0..0xFFFD, 0x10000..0xEFFFF
  ]

  attr_reader :source
  attr_writer :brace_name
  attr_writer :bracket_name
  attr_writer :slash_name

  def initialize(source)
    @source = StringReader.new(source)
    @version = nil
    @special_element_names = {:brace => nil, :bracket => nil, :slash => nil}
    @macros = {}
  end

  def parse
    result = parse_document.parse
    if result.success?
      return result.value
    else
      raise ZenithalParseError.new(result.message)
    end
  end

  def parse_document
    parser = Parser.exec(self) do
      document = Document.new
      children = !parse_nodes(false)
      !parse_eof
      children.each do |child|
        document.add(child)
      end
      next document
    end
    return parser
  end

  def parse_nodes(verbal)
    parser = Parser.exec(self) do
      parsers = [parse_element, parse_text(verbal), parse_line_comment, parse_block_comment]
      @special_element_names.each do |kind, name|
        parsers.push(parse_special_element(kind))
      end
      nodes = Nodes[]
      raw_nodes = !parsers.inject(:|).many
      raw_nodes.each do |raw_node|
        nodes << raw_node
      end
      next nodes
    end
    return parser
  end

  def parse_element
    parser = Parser.exec(self) do
      start_char = !parse_char_any([ELEMENT_START, MACRO_START])
      name = !parse_identifier
      marks = !parse_marks
      attributes = !parse_attributes.maybe || {}
      children_list = !parse_children_list
      if name == SYSTEM_INSTRUCTION_NAME
        !parse_space
      end
      if start_char == MACRO_START
        marks.push(:macro)
      end
      next create_nodes(name, marks, attributes, children_list)
    end
    return parser
  end

  def parse_special_element(kind)
    parser = Parser.exec(self) do
      unless @special_element_names[kind]
        !parse_none
      end
      !parse_char(SPECIAL_ELEMENT_STARTS[kind])
      children = !parse_nodes(false)
      !parse_char(SPECIAL_ELEMENT_ENDS[kind])
      next create_nodes(@special_element_names[kind], [], {}, [children])
    end
    return parser
  end

  def parse_marks
    return parse_mark.many
  end
  
  def parse_mark
    parsers = MARKS.map do |mark, query|
      next parse_char(query).map{|_| mark}
    end
    return parsers.inject(:|)
  end

  def parse_attributes
    parser = Parser.exec(self) do
      !parse_char(ATTRIBUTE_START)
      first_attribute = !parse_attribute(false)
      rest_attribtues = !parse_attribute(true).many
      attributes = first_attribute.merge(*rest_attribtues)
      !parse_char(ATTRIBUTE_END)
      next attributes
    end
    return parser
  end

  def parse_attribute(comma)
    parser = Parser.exec(self) do
      if comma
        !parse_char(ATTRIBUTE_SEPARATOR)
      end
      !parse_space
      name = !parse_identifier
      !parse_space
      !parse_char(ATTRIBUTE_EQUAL)
      !parse_space
      value = !parse_quoted_string
      !parse_space
      next {name => value}
    end
    return parser
  end

  def parse_quoted_string
    parser = Parser.exec(self) do
      !parse_char(ATTRIBUTE_VALUE_START)
      texts = !(parse_quoted_string_plain | parse_escape).many
      !parse_char(ATTRIBUTE_VALUE_END)
      next texts.join
    end
    return parser
  end

  def parse_quoted_string_plain
    parser = Parser.exec(self) do
      chars = !parse_char_out([ATTRIBUTE_VALUE_END, ESCAPE_START]).many(1)
      next chars.join
    end
    return parser
  end

  def parse_children_list
    parser = Parser.exec(self) do
      first_children = !(parse_empty_children | parse_children)
      rest_children_list = !parse_children.many
      children_list = [first_children] + rest_children_list
      next children_list
    end
    return parser
  end

  def parse_children
    parser = Parser.exec(self) do
      !parse_char(CONTENT_START)
      children = !parse_nodes(false)
      !parse_char(CONTENT_END)
      next children
    end
    return parser
  end

  def parse_empty_children
    parser = Parser.exec(self) do
      !parse_char(CONTENT_END)
      next Nodes[]
    end
    return parser
  end

  def parse_text(verbal)
    parser = Parser.exec(self) do
      texts = !(parse_text_plain(verbal) | parse_escape).many(1)
      next Text.new(texts.join, true, nil, false)
    end
    return parser
  end

  def parse_text_plain(verbal)
    parser = Parser.exec(self) do
      out_chars = [ESCAPE_START, CONTENT_END]
      unless verbal
        out_chars.push(ELEMENT_START, MACRO_START, CONTENT_START, COMMENT_DELIMITER)
        @special_element_names.each do |kind, name|
          out_chars.push(SPECIAL_ELEMENT_STARTS[kind], SPECIAL_ELEMENT_ENDS[kind]) if name
        end
      end
      chars = !parse_char_out(out_chars).many(1)
      next chars.join
    end
    return parser
  end

  def parse_line_comment
    parser = Parser.exec(self) do
      !parse_char(COMMENT_DELIMITER)
      !parse_char(COMMENT_DELIMITER)
      content = !parse_line_comment_content
      next Comment.new(" " + content.strip + " ")
    end
    return parser
  end

  def parse_line_comment_content
    parser = Parser.exec(self) do
      chars = !parse_char_out(["\n"]).many
      !parse_char("\n")
      next chars.join
    end
    return parser
  end

  def parse_block_comment
    parser = Parser.exec(self) do
      !parse_char(COMMENT_DELIMITER)
      !parse_char(CONTENT_START)
      content = !parse_block_comment_content
      !parse_char(CONTENT_END)
      !parse_char(COMMENT_DELIMITER)
      next Comment.new(" " + content.strip + " ")
    end
    return parser
  end

  def parse_block_comment_content
    parser = Parser.exec(self) do
      chars = !parse_char_out([CONTENT_END]).many
      next chars.join
    end
    return parser
  end

  def parse_escape
    parser = Parser.exec(self) do
      !parse_char(ESCAPE_START)
      char = !parse_char_any(ESCAPE_CHARS)
      next char
    end
    return parser
  end

  def parse_identifier
    parser = Parser.exec(self) do
      first_char = !parse_first_identifier_char
      rest_chars = !parse_middle_identifier_char.many
      identifier = first_char + rest_chars.join
      next identifier
    end
    return parser
  end

  def parse_first_identifier_char
    return parse_char_any(VALID_FIRST_IDENTIFIER_CHARS)
  end

  def parse_middle_identifier_char
    return parse_char_any(VALID_MIDDLE_IDENTIFIER_CHARS)
  end

  def parse_space
    return parse_char_any(SPACE_CHARS).many
  end

  def create_nodes(name, marks, attributes, children_list)
    nodes = Nodes[]
    unless marks.include?(:macro)
      if marks.include?(:instruction)
        unless children_list.size <= 1
          throw(:error, error_message("Processing instruction cannot have more than one argument"))
        end
        nodes = create_instructions(name, attributes, children_list.first)
      else
        unless marks.include?(:multiple) || children_list.size <= 1
          throw(:error, error_message("Normal node cannot have more than one argument"))
        end
        nodes = create_elements(name, attributes, children_list)
      end
    else
      nodes = process_macro(name, attributes, children_list)
    end
    return nodes
  end

  def create_instructions(target, attributes, children)
    instructions = Nodes[]
    if target == SYSTEM_INSTRUCTION_NAME
      @version = attributes["version"] if attributes["version"]
      @special_element_names[:brace] = attributes["brace"] if attributes["brace"]
      @special_element_names[:bracket] = attributes["bracket"] if attributes["bracket"]
      @special_element_names[:slash] = attributes["slash"] if attributes["slash"]
    elsif target == "xml"
      instruction = XMLDecl.new
      instruction.version = attributes["version"] || XMLDecl::DEFAULT_VERSION
      instruction.encoding = attributes["encoding"]
      instruction.standalone = attributes["standalone"]
      instructions << instruction
    else
      instruction = Instruction.new(target)
      actual_contents = []
      attributes.each do |key, value|
        actual_contents << "#{key}=\"#{value}\""
      end
      if children.first && !children.first.empty?
        actual_contents << children.first
      end
      instruction.content = actual_contents.join(" ")
      instructions << instruction
    end
    return instructions
  end

  def create_elements(name, attributes, children_list)
    elements = Nodes[]
    children_list.each do |children|
      element = Element.new(name)
      attributes.each do |key, value|
        element.add_attribute(key, value)
      end
      children.each do |child|
        element.add(child)
      end
      elements << element
    end
    return elements
  end

  def process_macro(name, attributes, children_list)
    elements = Nodes[]
    if @macros.key?(name)
      elements = @macros[name].call(attributes, children_list)    
    else
      throw(:error, error_message("No such macro"))
    end
    return elements
  end

  def register_macro(name, &block)
    @macros.store(name, block)
  end

  def error_message(message)
    return "[line #{@source.lineno}] #{message}"
  end

end