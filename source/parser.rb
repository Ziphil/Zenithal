# coding: utf-8


require 'pp'
require 'rexml/document'
include REXML

Encoding.default_external = "UTF-8"
$stdout.sync = true


class ZenithalParser

  TAG_START = "\\"
  ATTRIBUTE_START = "|"
  ATTRIBUTE_END = "|"
  ATTRIBUTE_EQUAL = "="
  ATTRIBUTE_VALUE_START = "\""
  ATTRIBUTE_VALUE_END = "\""
  ATTRIBUTE_SEPARATOR = ","
  CONTENT_START = "<"
  CONTENT_END = ">"
  BRACE_START = "{"
  BRACE_END = "}"
  BRACKET_START = "["
  BRACKET_END = "]"
  SLASH_START = "/"
  SLASH_END = "/"
  ENTITY_START = "&"
  ENTITY_CHAR_SYMBOL = "#"
  ENTITY_END = ">"
  COMMENT_DELIMITER = "#"
  INSTRUCTION_MARK = "?"
  TRIM_MARK = "!"
  VERBAL_MARK = "~"
  MULTIPLE_MARK = "*"
  SYSTEM_INSTRUCTION_NAME = "zml"
  ENTITIES = {"amp" => "&", "lt" => "<", "gt" => ">", "apos" => "'", "quot" => "\"",
              "lcub" => "{",  "rcub" => "}", "lbrace" => "{",  "rbrace" => "}", "lsqb" => "[",  "rsqb" => "]", "lbrack" => "[",  "rbrack" => "]",
              "sol" => "/", "bsol" => "\\", "verbar" => "|", "vert" => "|", "num" => "#"}
  VALID_START_CHARS = [0x3A, 0x41..0x5A, 0x5F, 0x61..0x7A, 0xC0..0xD6, 0xD8..0xF6, 0xF8..0x2FF, 0x370..0x37D, 0x37F..0x1FFF, 0x200C..0x200D, 
                       0x2070..0x218F, 0x2C00..0x2FEF, 0x3001..0xD7FF, 0xF900..0xFDCF, 0xFDF0..0xFFFD, 0x10000..0xEFFFF]
  VALID_MIDDLE_CHARS = [0x2D, 0x2E, 0x30..0x39, 0xB7, 0x0300..0x036F, 0x203F..0x2040]

  attr_writer :brace_name
  attr_writer :bracket_name
  attr_writer :slash_name

  def initialize(source)
    @source = StringReader.new(source)
    @version = nil
    @brace_name = nil
    @bracket_name = nil
    @slash_name = nil
  end

  def parse
    document = Document.new
    children = parse_nodes
    children.each do |child|
      document.add(child)
    end
    return document
  end

  def parse_nodes(option = {})
    children = []
    while char = @source.read
      if char == TAG_START
        @source.unread
        children.concat(parse_element)
      elsif @brace_name && char == BRACE_START
        @source.unread
        children << parse_brace
      elsif @bracket_name && char == BRACKET_START
        @source.unread
        children << parse_bracket
      elsif @slash_name && !option[:in_slash] && char == SLASH_START
        @source.unread
        children << parse_slash
      elsif char == COMMENT_DELIMITER
        @source.unread
        children << parse_comment
      elsif char == CONTENT_END || (@brace_name && char == BRACE_END) || (@bracket_name && char == BRACKET_END) || (@slash_name && char == SLASH_END)
        @source.unread
        break
      else
        @source.unread
        children << parse_text(option)
      end
    end
    return children
  end

  def parse_element
    unless @source.read == TAG_START
      raise ZenithalParseError.new(@source)
    end
    name, option = parse_element_name
    skip_spaces
    attributes, children_list = {}, []
    char = @source.read
    if char == ATTRIBUTE_START
      @source.unread
      attributes = parse_attributes
      skip_spaces
      char = @source.read
    end
    if char == CONTENT_START
      loop do
        children = []
        if option[:verbal] || option[:instruction]
          children = [parse_verbal_text(option)]
        else
          children = parse_nodes(option)
        end
        if option[:trim_indents]
          trim_indents(children)
        end
        children_list << children
        unless @source.read == CONTENT_END
          raise ZenithalParseError.new(@source)
        end
        space_count = skip_spaces
        unless @source.read == CONTENT_START
          @source.unread(space_count + 1)
          break
        end
      end
    elsif char == CONTENT_END
      children_list << []
    else
      raise ZenithalParseError.new(@source)
    end
    elements = []
    if option[:instruction]
      unless children_list.size <= 1
        raise ZenithalParseError.new(@source)
      end
      elements = create_instruction(name, attributes, children_list.first)
      if name == SYSTEM_INSTRUCTION_NAME
        skip_spaces
      end
    else
      unless option[:multiple] || children_list.size <= 1
        raise ZenithalParseError.new(@source)
      end
      elements = create_element(name, attributes, children_list)
    end
    return elements
  end

  def parse_element_name
    name, marks, option = "", [], {}
    while char = @source.read
      if char == ATTRIBUTE_START || char == CONTENT_START || char == CONTENT_END || char =~ /\s/
        @source.unread
        break
      elsif char == INSTRUCTION_MARK || char == TRIM_MARK || char == VERBAL_MARK || char == MULTIPLE_MARK
        marks << char
      elsif name.empty? && marks.empty? && ZenithalParser.valid_start_char?(char)
        name << char
      elsif !name.empty? && marks.empty? && ZenithalParser.valid_char?(char)
        name << char
      else
        raise ZenithalParseError.new(@source)
      end
    end
    if marks.include?(INSTRUCTION_MARK)
      option[:instruction] = true
    end
    if marks.include?(TRIM_MARK)
      option[:trim_indents] = true
    end
    if marks.include?(VERBAL_MARK)
      option[:verbal] = true
    end
    if marks.include?(MULTIPLE_MARK)
      option[:multiple] = true
    end
    return [name, option]
  end

  def create_element(name, attributes, children_list)
    elements = []
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

  def create_instruction(target, attributes, children)
    instructions = []
    if target == SYSTEM_INSTRUCTION_NAME
      @version = attributes["version"] if attributes["version"]
      @brace_name = attributes["brace"] if attributes["brace"]
      @bracket_name = attributes["bracket"] if attributes["bracket"]
      @slash_name = attributes["slash"] if attributes["slash"]
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
      if children[0] && !children[0].empty?
        actual_contents << children[0]
      end
      instruction.content = actual_contents.join(" ")
      instructions << instruction
    end
    return instructions
  end

  def parse_attributes
    unless @source.read == ATTRIBUTE_START
      raise ZenithalParseError.new(@source)
    end
    attributes = {}
    current_key = nil
    loop do
      key, value = parse_attribute
      attributes[key] = value
      char = @source.read
      if char == ATTRIBUTE_SEPARATOR
        skip_spaces
      elsif char == ATTRIBUTE_END
        @source.unread
        break
      else
        raise ZenithalParseError.new(@source)
      end
    end
    unless @source.read == ATTRIBUTE_END
      raise ZenithalParseError.new(@source)
    end
    return attributes
  end

  def parse_attribute
    key = parse_attribute_key
    skip_spaces
    unless @source.read == ATTRIBUTE_EQUAL
      raise ZenithalParseError.new(@source)
    end
    skip_spaces
    value = parse_attribute_value
    skip_spaces
    return [key, value]
  end

  def parse_attribute_key
    key = ""
    while char = @source.read
      if char == ATTRIBUTE_EQUAL || char =~ /\s/
        @source.unread
        break
      elsif key.empty? && ZenithalParser.valid_start_char?(char)
        key << char
      elsif !key.empty? && ZenithalParser.valid_char?(char)
        key << char
      else
        raise ZenithalParseError.new(@source)
      end
    end
    return key
  end

  def parse_attribute_value
    unless @source.read == ATTRIBUTE_VALUE_START
      raise ZenithalParseError.new(@source)
    end
    value = ""
    while char = @source.read
      if char == ATTRIBUTE_VALUE_END
        break
      elsif char == ENTITY_START
        @source.unread
        value << parse_entity
      else
        value << char
      end
    end
    return value
  end

  def parse_brace
    unless @source.read == BRACE_START
      raise ZenithalParseError.new(@source)
    end
    children = parse_nodes
    unless @source.read == BRACE_END
      raise ZenithalParseError.new(@source)
    end
    element = Element.new(@brace_name)
    children.each do |child|
      element.add(child)
    end
    return element
  end

  def parse_bracket
    unless @source.read == BRACKET_START
      raise ZenithalParseError.new(@source)
    end
    children = parse_nodes
    unless @source.read == BRACKET_END
      raise ZenithalParseError.new(@source)
    end
    element = Element.new(@bracket_name)
    children.each do |child|
      element.add(child)
    end
    return element
  end

  def parse_slash
    unless @source.read == SLASH_START
      raise ZenithalParseError.new(@source)
    end
    children = parse_nodes({:in_slash => true})
    unless @source.read == SLASH_END
      raise ZenithalParseError.new(@source)
    end
    element = Element.new(@slash_name)
    children.each do |child|
      element.add(child)
    end
    return element
  end

  def parse_comment
    unless @source.read == COMMENT_DELIMITER
      raise ZenithalParseError.new(@source)
    end
    char = @source.read
    string = ""
    if char == COMMENT_DELIMITER
      while char = @source.read
        if char == "\n"
          @source.unread
          break
        else
          string << char
        end
      end
    elsif char == CONTENT_START
      while char = @source.read
        if char == CONTENT_END
          next_char = @source.read
          if next_char == COMMENT_DELIMITER
            break
          else
            string << char
            @source.unread
          end
        else
          string << char
        end
      end
    else
      raise ZenithalParseError.new(@source)
    end
    comment = Comment.new(" #{string.strip} ")
    return comment
  end

  def parse_text(option = {})
    string = ""
    space = ""
    while char = @source.read
      if char == TAG_START || (@brace_name && char == BRACE_START) || (@bracket_name && char == BRACKET_START) || (@slash_name && char == SLASH_START)
        @source.unread
        break
      elsif char == CONTENT_END || (@brace_name && char == BRACE_END) || (@bracket_name && char == BRACKET_END) || (@slash_name && char == SLASH_END)
        @source.unread
        break
      elsif char == COMMENT_DELIMITER
        @source.unread
        break
      elsif char == ENTITY_START
        @source.unread
        string << parse_entity
      else
        string << char
      end
    end
    text = Text.new(string, true, nil, false)
    return text
  end

  def parse_verbal_text(option = {})
    string = ""
    while char = @source.read
      if char == CONTENT_END
        @source.unread
        break
      elsif char == ENTITY_START
        @source.unread
        string << parse_entity
      else
        string << char
      end
    end
    text = Text.new(string, true, nil, false)
    return text
  end

  def parse_entity
    unless @source.read == ENTITY_START
      raise ZenithalParseError.new(@source)
    end
    first_char = @source.read
    content = ""
    if first_char == ENTITY_CHAR_SYMBOL
      unless @source.read == "x"
        raise ZenithalParseError.new(@source)
      end
      while char = @source.read
        if char == ENTITY_END
          break
        elsif char =~ /[0-9a-fA-F]/
          content << char
        else
          raise ZenithalParseError.new(@source)
        end
      end
    else
      @source.unread
      while char = @source.read
        if char == ENTITY_END
          break
        elsif content.empty? && ZenithalParser.valid_start_char?(char)
          content << char
        elsif !content.empty? && ZenithalParser.valid_char?(char)
          content << char
        else
          raise ZenithalParseError.new(@source)
        end
      end
    end
    unless char == ENTITY_END
      raise ZenithalParseError.new(@source)
    end
    result = ""
    if first_char == ENTITY_CHAR_SYMBOL
      result << content.to_i(16).chr(Encoding::UTF_8)
    else
      if ENTITIES.key?(content)
        result << ENTITIES[content]
      else
        raise ZenithalParseError.new(@source)
      end
    end
    return result
  end

  def skip_spaces
    count = 0
    while (char = @source.read) =~ /\s/
      count += 1
    end
    @source.unread
    return count
  end

  def trim_spaces(children)
    if children[0].is_a?(Text)
      children[0].value = children[0].value.lstrip
    end
    if children[-1].is_a?(Text)
      children[-1].value = children[-1].value.rstrip
    end
  end

  def trim_indents(children)
    texts = []
    if children[-1].is_a?(Text)
      children[-1].value = children[-1].value.rstrip
    end
    children.each do |child|
      case child
      when Text
        texts << child
      when Parent
        texts.concat(child.all_texts)
      end
    end
    indent_length = 10000
    texts.each do |text|
      text.value.scan(/\n(\x20+)/) do |match|
        indent_length = [match[0].length, indent_length].min
      end
    end
    texts.each do |text|
      text.value = text.value.gsub(/\n(\x20+)/){"\n" + " " * ($1.length - indent_length)}
    end
    if children[0].is_a?(Text)
      children[0].value = children[0].value.lstrip
    end
  end

  def self.valid_start_char?(char)
    return VALID_START_CHARS.any?{|s| s === char.ord}
  end

  def self.valid_char?(char)
    return VALID_START_CHARS.any?{|s| s === char.ord} || VALID_MIDDLE_CHARS.any?{|s| s === char.ord}
  end

end


class StringReader

  attr_reader :lineno

  def initialize(string)
    @string = string
    @pos = -1
    @lineno = 1
  end

  def read
    @pos += 1
    char = @string[@pos]
    if char == "\n"
      @lineno += 1
    end
    return char
  end

  def unread(size = 1)
    size.times do
      char = @string[@pos]
      @pos -= 1
      if char == "\n"
        @lineno -= 1
      end
    end
  end

end


class Parent

  def all_texts
    texts = []
    self.children.each do |child|
      case child
      when Text
        texts << child
      when Parent
        texts.concat(child.all_texts)
      end
    end
    return texts
  end

end


class ZenithalParseError < StandardError

  def initialize(reader, message = "")
    whole_message = "[line #{reader.lineno}] #{message}"
    super(whole_message)
  end

end