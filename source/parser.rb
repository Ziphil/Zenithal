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
  COMMENT_START = "#"
  SYSTEM_INSTRUCTION_NAME = "zml"
  ENTITIES = {"amp" => "&amp;", "lt" => "&lt;", "gt" => "&gt;", "apos" => "&apos;", "quot" => "&quot;",
              "lcub" => "{",  "rcub" => "}", "lbrace" => "{",  "rbrace" => "}", "lsqb" => "[",  "rsqb" => "]", "lbrack" => "[",  "rbrack" => "]",
              "sol" => "/", "bsol" => "\\", "verbar" => "|", "vert" => "|", "num" => "#"}
  INVERSE_ENTITIES = {"&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "'" => "&apos;", "\"" => "&quot;"}

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

  def parse(option = {})
    children = []
    while (char = @source[@pointer += 1]) != nil
      if !option[:ignore_tag] && char == TAG_START
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
      elsif char == COMMENT_START
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
    if option[:trim]
      if children[0].is_a?(Text)
        children[0] = Text.new(children[0].to_s.lstrip, true, nil, true)
      end
      if children[-1].is_a?(Text)
        children[-1] = Text.new(children[-1].to_s.rstrip, true, nil, true)
      end
    end
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
      if option[:verbal] || option[:processing]
        children = [parse_verbal_text(option)]
      else
        children = parse(option)
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
    if option[:processing]
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
    name, option = "", {}
    while (char = @source[@pointer += 1]) != nil
      if char == ATTRIBUTE_START || char == CONTENT_START || char == CONTENT_END || char =~ /\s/
        @pointer -= 1
        break
      else
        name << char
      end
    end
    if match = name.match(/((!|\?|~)+)$/)
      suffixes = match[1].chars
      if suffixes.include?("!")
        option[:trim] = true
        if suffixes.count("!") >= 2
          option[:hard_trim] = true
        end
      end
      if suffixes.include?("?")
        option[:processing] = true
      end
      if suffixes.include?("~")
        option[:verbal] = true
      end
      name.gsub!(/((!|\?|~)+)$/, "")
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
    instruction = Instruction.new(target)
    if target == SYSTEM_INSTRUCTION_NAME
      @version = attributes["version"]
      @brace_name = attributes["brace"]
      @bracket_name = attributes["bracket"]
      @slash_name = attributes["slash"]
      instruction = nil
    else
      actual_content = ""
      attributes.each do |key, value|
        actual_content << "#{key}=\"#{value}\" "
      end
      if children[0] && !children[0].empty?
        actual_content << "#{children[0]} "
      end
      instruction.content = actual_content
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
    children = parse
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
    children = parse
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
    children = parse({:in_slash => true})
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
    unless @source[@pointer += 1] == COMMENT_START
      raise ZenithalParseError.new
    end
    string = ""
    while (char = @source[@pointer += 1]) != nil
      if char == "\n"
        @pointer -= 1
        break
      else
        string << char
      end
    end
    string << " "
    comment = Comment.new(string)
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
      elsif char == COMMENT_START
        @pointer -= 1
        break
      elsif char == ENTITY_START
        @pointer -= 1
        string << parse_entity
      else
        if option[:hard_trim]
          if char =~ /\s/
            space << char
          else
            string << space unless space.include?("\n")
            space = ""
            string << char
          end
        else
          string << char
        end
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
  end

end


class ZenithalParseError < StandardError

end