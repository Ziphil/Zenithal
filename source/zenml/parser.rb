# coding: utf-8


module Zenithal::ZenithalParserMethod

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
  CONTENT_DELIMITER = ";"
  SPECIAL_ELEMENT_STARTS = {:brace => "{", :bracket => "[", :slash => "/"}
  SPECIAL_ELEMENT_ENDS = {:brace => "}", :bracket => "]", :slash => "/"}
  COMMENT_DELIMITER = "#"
  SYSTEM_INSTRUCTION_NAME = "zml"
  MARK_CHARS = {:instruction => "?", :trim => "*", :verbal => "~", :multiple => "+"}
  ESCAPE_CHARS = ["&", "<", ">", "'", "\"", "{", "}", "[", "]", "/", "\\", "|", "`", "#", ";"]
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

  def parse
    if @whole
      parse_document
    else
      parse_nodes({})
    end
  end

  def parse_document
    document = REXML::Document.new
    check_version
    children = parse_nodes({})
    if @exact
      parse_eof 
    end
    children.each do |child|
      document.add(child)
    end
    return document
  end

  def parse_nodes(options)
    nodes = nil
    if options[:plugin]
      nodes = options[:plugin].send(:parse)
    elsif options[:verbal]
      raw_nodes = many(->{parse_text(options)})
      nodes = raw_nodes.inject(REXML::Nodes[], :<<)
    else
      parsers = []
      parsers << ->{parse_element(options)}
      if options[:in_slash]
        next_options = options.clone
        next_options.delete(:in_slash)
      else
        next_options = options
      end
      @special_element_names.each do |kind, name|
        unless kind == :slash && options[:in_slash]
          parsers << ->{parse_special_element(kind, next_options)}
        end
      end
      parsers << ->{parse_comment(options)}
      parsers << ->{parse_text(options)}
      raw_nodes = many(->{choose(*parsers)})
      nodes = raw_nodes.inject(REXML::Nodes[], :<<)
    end
    return nodes
  end

  def parse_element(options)
    name, marks, attributes, macro = parse_tag(options)
    next_options = determine_options(name, marks, attributes, macro, options)
    children_list = parse_children_list(next_options)
    if name == SYSTEM_INSTRUCTION_NAME
      parse_space
    end
    if macro
      element = process_macro(name, marks, attributes, children_list, options)
    else
      element = create_element(name, marks, attributes, children_list, options)
    end
    return element
  end

  def parse_special_element(kind, options)
    parse_char(SPECIAL_ELEMENT_STARTS[kind])
    if kind == :slash
      next_options = options.clone
      next_options[:in_slash] = true
    else
      next_options = options
    end
    children = parse_nodes(next_options)
    parse_char(SPECIAL_ELEMENT_ENDS[kind])
    element = create_special_element(kind, children, options)
    return element
  end

  def parse_tag(options)
    start_char = parse_char_any([ELEMENT_START, MACRO_START])
    name = parse_identifier(options)
    marks = parse_marks(options)
    attributes = maybe(->{parse_attributes(options)}) || {}
    macro = start_char == MACRO_START
    return name, marks, attributes, macro
  end

  def parse_marks(options)
    marks = many(->{parse_mark(options)})
    return marks
  end
  
  def parse_mark(options)
    parsers = MARK_CHARS.map do |mark, query|
      next ->{parse_char(query).yield_self{|_| mark}}
    end
    mark = choose(*parsers)
    return mark
  end

  def parse_attributes(options)
    parse_char(ATTRIBUTE_START)
    first_attribute = parse_attribute(true, options)
    rest_attribtues = many(->{parse_attribute(false, options)})
    attributes = first_attribute.merge(*rest_attribtues)
    parse_char(ATTRIBUTE_END)
    return attributes
  end

  def parse_attribute(first, options)
    unless first
      parse_char(ATTRIBUTE_SEPARATOR) 
    end
    parse_space
    name = parse_identifier(options)
    parse_space
    value = maybe(->{parse_attribute_value(options)}) || name
    parse_space
    attribute = {name => value}
    return attribute
  end

  def parse_attribute_value(options)
    parse_char(ATTRIBUTE_EQUAL)
    parse_space
    value = parse_string(options)
    return value
  end

  def parse_string(options)
    parse_char(STRING_START)
    strings = many(->{parse_string_plain_or_escape(options)})
    parse_char(STRING_END)
    string = strings.join
    return string
  end

  def parse_string_plain(options)
    chars = many(->{parse_char_out([STRING_END, ESCAPE_START])}, 1..)
    string = chars.join
    return string
  end

  def parse_string_plain_or_escape(options)
    string = choose(->{parse_escape(:string, options)}, ->{parse_string_plain(options)})
    return string
  end

  def parse_children_list(options)
    if @version == "1.0"
      children_list = parse_children_chain(options)
    else
      children_list = choose(->{parse_empty_children_chain(options)}, ->{parse_children_chain(options)})
    end
    return children_list
  end

  def parse_children_chain(options)
    if @version == "1.0"
      first_children = choose(->{parse_empty_children(options)}, ->{parse_children(options)})
      rest_children_list = many(->{parse_children(options)})
      children_list = [first_children] + rest_children_list
    else
      children_list = many(->{parse_children(options)}, 1..)
    end
    return children_list
  end

  def parse_empty_children_chain(options)
    children = parse_empty_children(options)
    children_list = [children]
    return children_list
  end

  def parse_children(options)
    parse_char(CONTENT_START)
    children = parse_nodes(options)
    parse_char(CONTENT_END)
    return children
  end

  def parse_empty_children(options)
    if @version == "1.0"
      parse_char(CONTENT_END)
      children = REXML::Nodes[]
    else
      parse_char(CONTENT_DELIMITER)
      children = REXML::Nodes[]
    end
    return children
  end

  def parse_text(options)
    raw_texts = many(->{parse_text_plain_or_escape(options)}, 1..)
    text = create_text(raw_texts.join, options)
    return text
  end

  def parse_text_plain(options)
    out_chars = [ESCAPE_START, CONTENT_END]
    unless options[:verbal]
      out_chars.push(ELEMENT_START, MACRO_START, CONTENT_START, COMMENT_DELIMITER)
      if @version == "1.1"
        out_chars.push(CONTENT_DELIMITER)
      end
      @special_element_names.each do |kind, name|
        out_chars.push(SPECIAL_ELEMENT_STARTS[kind], SPECIAL_ELEMENT_ENDS[kind])
      end
    end
    chars = many(->{parse_char_out(out_chars)}, 1..)
    string = chars.join
    return string
  end

  def parse_text_plain_or_escape(options)
    string = choose(->{parse_escape(:text, options)}, ->{parse_text_plain(options)})
    return string
  end

  def parse_comment(options)
    parse_char(COMMENT_DELIMITER)
    comment = choose(->{parse_line_comment(options)}, ->{parse_block_comment(options)})
    return comment
  end

  def parse_line_comment(options)
    parse_char(COMMENT_DELIMITER)
    content = parse_line_comment_content(options)
    parse_char("\n")
    comment = create_comment(:line, content, options)
    return comment
  end

  def parse_line_comment_content(options)
    chars = many(->{parse_char_out(["\n"])})
    content = chars.join
    return content
  end

  def parse_block_comment(options)
    parse_char(CONTENT_START)
    content = parse_block_comment_content(options)
    parse_char(CONTENT_END)
    if @version == "1.0"
      parse_char(COMMENT_DELIMITER)
    end
    comment = create_comment(:block, content, options)
    return comment
  end

  def parse_block_comment_content(options)
    chars = many(->{parse_char_out([CONTENT_END])})
    content = chars.join
    return content
  end

  def parse_escape(place, options)
    parse_char(ESCAPE_START)
    char = parse_char
    escape = create_escape(place, char, options)
    return escape
  end

  def parse_identifier(options)
    first_char = parse_first_identifier_char(options)
    rest_chars = many(->{parse_middle_identifier_char(options)})
    identifier = first_char + rest_chars.join
    return identifier
  end

  def parse_first_identifier_char(options)
    char = parse_char_any(VALID_FIRST_IDENTIFIER_CHARS)
    return char
  end

  def parse_middle_identifier_char(options)
    char = parse_char_any(VALID_MIDDLE_IDENTIFIER_CHARS)
    return char
  end

  def parse_space
    space = many(->{parse_char_any(SPACE_CHARS)})
    return space
  end

  def determine_options(name, marks, attributes, macro, options)
    if marks.include?(:verbal)
      options = options.clone
      options[:verbal] = true
    end
    if macro && @plugins.key?(name)
      options = options.clone
      options[:plugin] = @plugins[name].call(attributes)
    end
    return options
  end

  def create_element(name, marks, attributes, children_list, options)
    nodes = REXML::Nodes[]
    if marks.include?(:trim)
      children_list.each do |children|
        children.trim_indents
      end
    end
    if marks.include?(:instruction)
      unless children_list.size <= 1
        throw_custom("Processing instruction cannot have more than one argument")
      end
      nodes = create_instruction(name, attributes, children_list.first, options)
    else
      unless marks.include?(:multiple) || children_list.size <= 1
        throw_custom("Normal element cannot have more than one argument")
      end
      nodes = create_normal_element(name, attributes, children_list, options)
    end
    return nodes
  end

  def create_instruction(target, attributes, children, options)
    nodes = REXML::Nodes[]
    if target == SYSTEM_INSTRUCTION_NAME
      @version = attributes["version"] if attributes["version"]
      @special_element_names[:brace] = attributes["brace"] if attributes["brace"]
      @special_element_names[:bracket] = attributes["bracket"] if attributes["bracket"]
      @special_element_names[:slash] = attributes["slash"] if attributes["slash"]
    elsif target == "xml"
      instruction = REXML::XMLDecl.new
      instruction.version = attributes["version"] || REXML::XMLDecl::DEFAULT_VERSION
      instruction.encoding = attributes["encoding"]
      instruction.standalone = attributes["standalone"]
      nodes << instruction
    else
      instruction = REXML::Instruction.new(target)
      actual_contents = []
      attributes.each do |key, value|
        actual_contents << "#{key}=\"#{value}\""
      end
      if children.first && !children.first.empty?
        actual_contents << children.first
      end
      instruction.content = actual_contents.join(" ")
      nodes << instruction
    end
    return nodes
  end

  def create_normal_element(name, attributes, children_list, options)
    nodes = REXML::Nodes[]
    children_list.each do |children|
      element = REXML::Element.new(name)
      attributes.each do |key, value|
        element.add_attribute(key, value)
      end
      children.each do |child|
        element.add(child)
      end
      nodes << element
    end
    return nodes
  end

  def create_special_element(kind, children, options)
    name = @special_element_names[kind]
    if name
      nodes = create_element(name, [], {}, [children], options)
    else
      throw_custom("No name specified for #{kind} elements")
    end
    return nodes
  end

  def create_text(raw_text, options)
    text = REXML::Text.new(raw_text, true, nil, false)
    return text
  end

  def create_comment(kind, content, options)
    comment = REXML::Comment.new(" " + content.strip + " ")
    return comment
  end

  def create_escape(place, char, options)
    unless ESCAPE_CHARS.include?(char)
      throw_custom("Invalid escape")
    end
    return char
  end

  def process_macro(name, marks, attributes, children_list, options)
    elements = REXML::Nodes[]
    if @macros.key?(name)
      raw_elements = @macros[name].call(attributes, children_list)
      raw_elements.each do |raw_element|
        elements << raw_element
      end
    elsif @plugins.key?(name)
      elements = children_list.first
    else
      throw_custom("No such macro '#{name}'")
    end
    return elements
  end

  def check_version
    string = @source.string
    if match = string.match(/\\zml\?\s*\|.*version\s*=\s*"(\d+\.\d+)".*\|/)
      @version = match[1]
    end
  end

end


class Zenithal::ZenithalParser < Zenithal::Parser

  include Zenithal::ZenithalParserMethod

  attr_accessor :exact
  attr_accessor :whole

  def initialize(source)
    super(source)
    @exact = true
    @whole = true
    @fallback_version = "1.0"
    @version = "1.0"
    @fallback_special_element_names = {:brace => nil, :bracket => nil, :slash => nil}
    @special_element_names = {:brace => nil, :bracket => nil, :slash => nil}
    @macros = {}
    @plugins = {}
  end

  def update(source)
    super(source)
    @version = @fallback_version
    @special_element_names = @fallback_special_element_names
  end

  # Registers a macro.
  # To the argument block will be passed two arguments: the first is a hash of the attributes, the second is a list of the children nodes.
  def register_macro(name, &block)
    @macros.store(name, block)
  end

  def unregister_macro(name)
    @macros.delete(name)
  end

  # Registers a plugin, which enables us to apply another parser in certain macros.
  # If a class instance is passed, simply an instance of that class will be created and used as a custom parser.
  # If a block is passed, it will be called to create a custom parser.
  # To this block will be passed one argument: the attributes which are specified to the macro.
  def register_plugin(name, clazz = nil, &block)
    if clazz
      block = lambda{|_| clazz.new(@source)}
    end
    @plugins.store(name, block)
  end

  def unregister_plugin(name)
    @plugins.delete(name)
  end

  def version=(version)
    @version = version
    @fallback_version = version
  end

  def brace_name=(name)
    @fallback_special_element_names[:brace] = name
    @special_element_names[:brace] = name
  end

  def bracket_name=(name)
    @fallback_special_element_names[:bracket] = name
    @special_element_names[:bracket] = name
  end

  def slash_name=(name)
    @fallback_special_element_names[:slash] = name
    @special_element_names[:slash] = name
  end

end