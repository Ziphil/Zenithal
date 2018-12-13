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
  ENTITY_END = ";"
  COMMENT_DELIMITER = "#"
  INSTRUCTION_MARK = "?"
  TRIM_MARK = "!"
  VERBAL_MARK = "~"
  SYSTEM_INSTRUCTION_NAME = "zml"
  ENTITIES = {"amp" => "&amp;", "lt" => "&lt;", "gt" => "&gt;", "apos" => "&apos;", "quot" => "&quot;",
              "lcub" => "{",  "rcub" => "}", "lbrace" => "{",  "rbrace" => "}", "lsqb" => "[",  "rsqb" => "]", "lbrack" => "[",  "rbrack" => "]",
              "sol" => "/", "bsol" => "\\", "verbar" => "|", "vert" => "|", "num" => "#"}
  INVERSE_ENTITIES = {"&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "'" => "&apos;", "\"" => "&quot;"}
  VALID_START_CHARS = [0x3A, 0x41..0x5A, 0x5F, 0x61..0x7A, 0xC0..0xD6, 0xD8..0xF6, 0xF8..0x2FF, 0x370..0x37D, 0x37F..0x1FFF, 0x200C..0x200D, 
                       0x2070..0x218F, 0x2C00..0x2FEF, 0x3001..0xD7FF, 0xF900..0xFDCF, 0xFDF0..0xFFFD, 0x10000..0xEFFFF]
  VALID_MIDDLE_CHARS = [0x2D, 0x2E, 0x30..0x39, 0xB7, 0x0300..0x036F, 0x203F..0x2040]

  attr_writer :brace_name
  attr_writer :bracket_name
  attr_writer :slash_name

  def initialize(source)
    @source = source.chars
    @version = nil
    @brace_name = nil
    @bracket_name = nil
    @slash_name = nil
    @pointer = -1
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
    while (char = @source[@pointer += 1]) != nil
      if char == TAG_START
        @pointer -= 1
        children << parse_element
      elsif @brace_name && char == BRACE_START
        @pointer -= 1
        children << parse_brace
      elsif @bracket_name && char == BRACKET_START
        @pointer -= 1
        children << parse_bracket
      elsif @slash_name && !option[:in_slash] && char == SLASH_START
        @pointer -= 1
        children << parse_slash
      elsif char == COMMENT_DELIMITER
        @pointer -= 1
        children << parse_comment
      elsif char == CONTENT_END || (@brace_name && char == BRACE_END) || (@bracket_name && char == BRACKET_END) || (@slash_name && char == SLASH_END)
        @pointer -= 1
        break
      else
        @pointer -= 1
        children << parse_text(option)
      end
    end
    children.compact!
    return children
  end

  def parse_element
    unless @source[@pointer += 1] == TAG_START
      raise ZenithalParseError.new
    end
    name, option = parse_element_name
    skip_spaces
    attributes, children = {}, []
    char = @source[@pointer += 1]
    if char == ATTRIBUTE_START
      @pointer -= 1
      attributes = parse_attributes
      skip_spaces
      char = @source[@pointer += 1]
    end
    if char == CONTENT_START
      if option[:verbal] || option[:instruction]
        children = [parse_verbal_text(option)]
      else
        children = parse_nodes(option)
      end
      if option[:trim_spaces]
        trim_spaces(children)
      end
      if option[:trim_indents]
        trim_indents(children)
      end
      unless @source[@pointer += 1] == CONTENT_END
        raise ZenithalParseError.new
      end
    elsif char == CONTENT_END
      children = []
    else
      raise ZenithalParseError.new
    end
    element = nil
    if option[:instruction]
      element = create_instruction(name, attributes, children)
      if name == SYSTEM_INSTRUCTION_NAME
        skip_spaces
      end
    else
      element = create_element(name, attributes, children)
    end
    return element
  end

  def parse_element_name
    name, marks, option = "", [], {}
    while (char = @source[@pointer += 1]) != nil
      if char == ATTRIBUTE_START || char == CONTENT_START || char == CONTENT_END || char =~ /\s/
        @pointer -= 1
        break
      elsif char == INSTRUCTION_MARK || char == TRIM_MARK || char == VERBAL_MARK
        marks << char
      elsif name.empty? && marks.empty? && ZenithalParser.valid_start_char?(char)
        name << char
      elsif !name.empty? && marks.empty? && ZenithalParser.valid_char?(char)
        name << char
      else
        raise ZenithalParseError.new
      end
    end
    if marks.include?(INSTRUCTION_MARK)
      option[:instruction] = true
    end
    if marks.include?(TRIM_MARK)
      if marks.count(TRIM_MARK) <= 1
        option[:trim_spaces] = true
      else
        option[:trim_indents] = true
      end
    end
    if marks.include?(VERBAL_MARK)
      option[:verbal] = true
    end
    return [name, option]
  end

  def create_element(name, attributes, children)
    element = Element.new(name)
    attributes.each do |key, value|
      element.add_attribute(key, value)
    end
    children.each do |child|
      element.add(child)
    end
    return element
  end

  def create_instruction(target, attributes, children)
    instruction = nil
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
    end
    return instruction
  end

  def parse_attributes
    unless @source[@pointer += 1] == ATTRIBUTE_START
      raise ZenithalParseError.new
    end
    attributes = {}
    current_key = nil
    while (char = @source[@pointer += 1]) != nil
      if char == ATTRIBUTE_SEPARATOR
        skip_spaces
      elsif char == ATTRIBUTE_END
        @pointer -= 1
        break
      else
        @pointer -= 1
        key, value = parse_attribute
        attributes[key] = value
      end
    end
    unless @source[@pointer += 1] == ATTRIBUTE_END
      raise ZenithalParseError.new
    end
    return attributes
  end

  def parse_attribute
    key = parse_attribute_key
    skip_spaces
    unless @source[@pointer += 1] == ATTRIBUTE_EQUAL
      raise ZenithalParseError.new
    end
    skip_spaces
    value = parse_attribute_value
    skip_spaces
    return [key, value]
  end

  def parse_attribute_key
    key = ""
    while (char = @source[@pointer += 1]) != nil
      if char == ATTRIBUTE_EQUAL || char =~ /\s/
        @pointer -= 1
        break
      else
        key << char
      end
    end
    return key
  end

  def parse_attribute_value
    unless @source[@pointer += 1] == ATTRIBUTE_VALUE_START
      raise ZenithalParseError.new
    end
    value = ""
    while (char = @source[@pointer += 1]) != nil
      if char == ATTRIBUTE_VALUE_END
        break
      else
        value << char
      end
    end
    return value
  end

  def parse_brace
    unless @source[@pointer += 1] == BRACE_START
      raise ZenithalParseError.new
    end
    children = parse_nodes
    unless @source[@pointer += 1] == BRACE_END
      raise ZenithalParseError.new
    end
    element = Element.new(@brace_name)
    children.each do |child|
      element.add(child)
    end
    return element
  end

  def parse_bracket
    unless @source[@pointer += 1] == BRACKET_START
      raise ZenithalParseError.new
    end
    children = parse_nodes
    unless @source[@pointer += 1] == BRACKET_END
      raise ZenithalParseError.new
    end
    element = Element.new(@bracket_name)
    children.each do |child|
      element.add(child)
    end
    return element
  end

  def parse_slash
    unless @source[@pointer += 1] == SLASH_START
      raise ZenithalParseError.new
    end
    children = parse_nodes({:in_slash => true})
    unless @source[@pointer += 1] == SLASH_END
      raise ZenithalParseError.new
    end
    element = Element.new(@slash_name)
    children.each do |child|
      element.add(child)
    end
    return element
  end

  def parse_comment
    unless @source[@pointer += 1] == COMMENT_DELIMITER
      raise ZenithalParseError.new
    end
    char = @source[@pointer += 1]
    string = ""
    if char == COMMENT_DELIMITER
      while (char = @source[@pointer += 1]) != nil
        if char == "\n"
          @pointer -= 1
          break
        else
          string << char
        end
      end
    elsif char == CONTENT_START
      while (char = @source[@pointer += 1]) != nil
        if char == CONTENT_END
          next_char = @source[@pointer += 1]
          if next_char == COMMENT_DELIMITER
            break
          else
            string << char
            @pointer -= 1
          end
        else
          string << char
        end
      end
    end
    comment = Comment.new(" #{string.strip} ")
    return comment
  end

  def parse_text(option = {})
    string = ""
    space = ""
    while (char = @source[@pointer += 1]) != nil
      if char == TAG_START || (@brace_name && char == BRACE_START) || (@bracket_name && char == BRACKET_START) || (@slash_name && char == SLASH_START)
        @pointer -= 1
        break
      elsif char == CONTENT_END || (@brace_name && char == BRACE_END) || (@bracket_name && char == BRACKET_END) || (@slash_name && char == SLASH_END)
        @pointer -= 1
        break
      elsif char == COMMENT_DELIMITER
        @pointer -= 1
        break
      elsif char == ENTITY_START
        @pointer -= 1
        string << parse_entity
      else
        string << char
      end
    end
    text = Text.new(string, true, nil, true)
    return text
  end

  def parse_verbal_text(option = {})
    string = ""
    while (char = @source[@pointer += 1]) != nil
      if char == CONTENT_END
        @pointer -= 1
        break
      elsif char == ENTITY_START
        @pointer -= 1
        string << parse_entity
      else
        if INVERSE_ENTITIES.key?(char)
          string << INVERSE_ENTITIES[char]
        else
          string << char
        end
      end
    end
    text = Text.new(string, true, nil, true)
    return text
  end

  def parse_entity
    unless @source[@pointer += 1] == ENTITY_START
      raise ZenithalParseError.new
    end
    content = ""
    while (char = @source[@pointer += 1]) != nil
      if char == ENTITY_END
        break
      else
        content << char
      end
    end
    unless @source[@pointer] == ENTITY_END
      raise ZenithalParseError.new
    end
    result = ENTITIES[content] || "&#{content};"
    return result
  end

  def skip_spaces
    count = 0
    while (char = @source[@pointer += 1]) =~ /\s/
      count += 1
    end
    @pointer -= 1
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

end