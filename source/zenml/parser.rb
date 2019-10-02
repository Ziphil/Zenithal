# coding: utf-8


require 'pp'
require 'rexml/document'
include REXML


module ZenithalParserMethod

  ELEMENT_START = "\\"
  MACRO_START = "&"
  ESCAPE_START = "`"
  ATTRIBUTE_START = "|"
  ATTRIBUTE_END = "|"
  ATTRIBUTE_EQUAL = "="
  ATTRIBUTE_SEPARATOR = ","
  STRING_START = "\""
  STRING_END = "\""
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

  private

  def parse_document
    parser = Parser.build(self) do
      document = Document.new
      children = +parse_nodes({})
      +parse_eof
      children.each do |child|
        document.add(child)
      end
      next document
    end
    return parser
  end

  def parse_nodes(options)
    parser = Parser.build(self) do
      parsers = [parse_text(options)]
      unless options[:verbal]
        parsers.push(parse_element(options), parse_line_comment(options), parse_block_comment(options))
        @special_element_names.each do |kind, name|
          parsers.push(parse_special_element(kind, options))
        end
      end
      nodes = Nodes[]
      raw_nodes = +parsers.inject(:|).many
      raw_nodes.each do |raw_node|
        nodes << raw_node
      end
      next nodes
    end
    return parser
  end

  def parse_element(options)
    parser = Parser.build(self) do
      start_char = +parse_char_any([ELEMENT_START, MACRO_START])
      name = +parse_identifier(options)
      marks = +parse_marks(options)
      attributes = +parse_attributes(options).maybe || {}
      next_options = determine_options(name, marks, attributes, start_char == MACRO_START, options)
      children_list = +parse_children_list(next_options)
      if name == SYSTEM_INSTRUCTION_NAME
        +parse_space
      end
      if start_char == MACRO_START
        next process_macro(name, marks, attributes, children_list, options)
      else
        next create_nodes(name, marks, attributes, children_list, options)
      end
    end
    return parser
  end

  def determine_options(name, marks, attributes, macro, options)
    if marks.include?(:verbal)
      options = options.clone
      options[:verbal] = true
    end
    return options
  end

  def parse_special_element(kind, options)
    parser = Parser.build(self) do
      unless @special_element_names[kind]
        +parse_none
      end
      +parse_char(SPECIAL_ELEMENT_STARTS[kind])
      children = +parse_nodes(options)
      +parse_char(SPECIAL_ELEMENT_ENDS[kind])
      next create_nodes(@special_element_names[kind], [], {}, [children], options)
    end
    return parser
  end

  def parse_marks(options)
    return parse_mark(options).many
  end
  
  def parse_mark(options)
    parsers = MARKS.map do |mark, query|
      next parse_char(query).map{|_| mark}
    end
    return parsers.inject(:|)
  end

  def parse_attributes(options)
    parser = Parser.build(self) do
      +parse_char(ATTRIBUTE_START)
      first_attribute = +parse_attribute(true, options)
      rest_attribtues = +parse_attribute(false, options).many
      attributes = first_attribute.merge(*rest_attribtues)
      +parse_char(ATTRIBUTE_END)
      next attributes
    end
    return parser
  end

  def parse_attribute(first, options)
    parser = Parser.build(self) do
      +parse_char(ATTRIBUTE_SEPARATOR) unless first
      +parse_space
      name = +parse_identifier(options)
      +parse_space
      value = +parse_attribute_value(options).maybe || name
      +parse_space
      next {name => value}
    end
    return parser
  end

  def parse_attribute_value(options)
    parser = Parser.build(self) do
      +parse_char(ATTRIBUTE_EQUAL)
      +parse_space
      value = +parse_string(options)
      next value
    end
    return parser
  end

  def parse_string(options)
    parser = Parser.build(self) do
      +parse_char(STRING_START)
      strings = +(parse_string_plain(options) | parse_escape(options)).many
      +parse_char(STRING_END)
      next strings.join
    end
    return parser
  end

  def parse_string_plain(options)
    parser = Parser.build(self) do
      chars = +parse_char_out([STRING_END, ESCAPE_START]).many(1)
      next chars.join
    end
    return parser
  end

  def parse_children_list(options)
    parser = Parser.build(self) do
      first_children = +(parse_empty_children(options) | parse_children(options))
      rest_children_list = +parse_children(options).many
      children_list = [first_children] + rest_children_list
      next children_list
    end
    return parser
  end

  def parse_children(options)
    parser = Parser.build(self) do
      +parse_char(CONTENT_START)
      children = +parse_nodes(options)
      +parse_char(CONTENT_END)
      next children
    end
    return parser
  end

  def parse_empty_children(options)
    parser = Parser.build(self) do
      +parse_char(CONTENT_END)
      next Nodes[]
    end
    return parser
  end

  def parse_text(options)
    parser = Parser.build(self) do
      raw_texts = +(parse_text_plain(options) | parse_escape(options)).many(1)
      next create_texts(raw_texts.join, options)
    end
    return parser
  end

  def parse_text_plain(options)
    parser = Parser.build(self) do
      out_chars = [ESCAPE_START, CONTENT_END]
      unless options[:verbal]
        out_chars.push(ELEMENT_START, MACRO_START, CONTENT_START, COMMENT_DELIMITER)
        @special_element_names.each do |kind, name|
          out_chars.push(SPECIAL_ELEMENT_STARTS[kind], SPECIAL_ELEMENT_ENDS[kind]) if name
        end
      end
      chars = +parse_char_out(out_chars).many(1)
      next chars.join
    end
    return parser
  end

  def parse_line_comment(options)
    parser = Parser.build(self) do
      +parse_char(COMMENT_DELIMITER)
      +parse_char(COMMENT_DELIMITER)
      content = +parse_line_comment_content(options)
      +parse_char("\n")
      next create_comments(:line, content, options)
    end
    return parser
  end

  def parse_line_comment_content(options)
    parser = Parser.build(self) do
      chars = +parse_char_out(["\n"]).many
      next chars.join
    end
    return parser
  end

  def parse_block_comment(options)
    parser = Parser.build(self) do
      +parse_char(COMMENT_DELIMITER)
      +parse_char(CONTENT_START)
      content = +parse_block_comment_content(options)
      +parse_char(CONTENT_END)
      +parse_char(COMMENT_DELIMITER)
      next create_comments(:block, content, options)
    end
    return parser
  end

  def parse_block_comment_content(options)
    parser = Parser.build(self) do
      chars = +parse_char_out([CONTENT_END]).many
      next chars.join
    end
    return parser
  end

  def parse_escape(options)
    parser = Parser.build(self) do
      +parse_char(ESCAPE_START)
      char = +parse_char_any(ESCAPE_CHARS)
      next char
    end
    return parser
  end

  def parse_identifier(options)
    parser = Parser.build(self) do
      first_char = +parse_first_identifier_char(options)
      rest_chars = +parse_middle_identifier_char(options).many
      identifier = first_char + rest_chars.join
      next identifier
    end
    return parser
  end

  def parse_first_identifier_char(options)
    return parse_char_any(VALID_FIRST_IDENTIFIER_CHARS)
  end

  def parse_middle_identifier_char(options)
    return parse_char_any(VALID_MIDDLE_IDENTIFIER_CHARS)
  end

  def parse_space
    return parse_char_any(SPACE_CHARS).many
  end

  def create_nodes(name, marks, attributes, children_list, options)
    nodes = Nodes[]
    if marks.include?(:trim)
      children_list.each do |children|
        children.trim_indents
      end
    end
    if marks.include?(:instruction)
      unless children_list.size <= 1
        throw(:error, error_message("Processing instruction cannot have more than one argument"))
      end
      nodes = create_instructions(name, attributes, children_list.first, options)
    else
      unless marks.include?(:multiple) || children_list.size <= 1
        throw(:error, error_message("Normal node cannot have more than one argument"))
      end
      nodes = create_elements(name, attributes, children_list, options)
    end
    return nodes
  end

  def create_instructions(target, attributes, children, options)
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

  def create_elements(name, attributes, children_list, options)
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

  def create_texts(raw_text, options)
    texts = Nodes[]
    texts << Text.new(raw_text, true, nil, false)
    return texts
  end

  def create_comments(kind, content, options)
    comments = Nodes[]
    comments << Comment.new(" " + content.strip + " ")
    return comments
  end

  def process_macro(name, marks, attributes, children_list, options)
    elements = Nodes[]
    if @macros.key?(name)
      raw_elements = @macros[name].call(attributes, children_list)
      raw_elements.each do |raw_element|
        elements << raw_element
      end
    else
      throw(:error, error_message("No such macro"))
    end
    return elements
  end

  def error_message(message)
    return "[line #{@source.lineno}] #{message}"
  end

end


class ZenithalParser

  include CommonParserMethod
  include ZenithalParserMethod

  attr_reader :source

  def initialize(source)
    @source = StringReader.new(source)
    @version = nil
    @special_element_names = {:brace => nil, :bracket => nil, :slash => nil}
    @macros = {}
  end

  def parse
    result = parse_document.exec
    if result.success?
      return result.value
    else
      raise ZenithalParseError.new(result.message)
    end
  end

  def register_macro(name, &block)
    @macros.store(name, block)
  end

  def brace_name=(name)
    @special_element_names[:brace] = name
  end

  def bracket_name=(name)
    @special_element_names[:bracket] = name
  end

  def slash_name=(name)
    @special_element_names[:slash] = name
  end

end