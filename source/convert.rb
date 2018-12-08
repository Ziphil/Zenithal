# coding: utf-8


require 'pp'

Encoding.default_external = "UTF-8"
$stdout.sync = true


class ZenithalConverter

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
  SYSTEM_PROCESSING_NAME = "zml"
  ENTITIES = {"amp" => "&amp;", "lt" => "&lt;", "gt" => "&gt;", "apos" => "&apos;", "quot" => "&quot;",
              "lcub" => "{",  "rcub" => "}", "lbrace" => "{",  "rbrace" => "}", "lsqb" => "[",  "rsqb" => "]", "lbrack" => "[",  "rbrack" => "]",
              "sol" => "/", "bsol" => "\\", "verbar" => "|", "vert" => "|", "num" => "#"}

  def initialize(source)
    @source = source.chars
    @version = nil
    @brace_name = nil
    @bracket_name = nil
    @slash_name = nil
    @pointer = -1
  end

  def convert(option = {})
    result = ""
    while (char = @source[@pointer += 1]) != nil
      if !option[:ignore_tag] && char == TAG_START
        @pointer -= 1
        result << convert_tag
      elsif @brace_name && char == BRACE_START
        @pointer -= 1
        result << convert_brace
      elsif @bracket_name && char == BRACKET_START
        @pointer -= 1
        result << convert_bracket
      elsif @slash_name && !option[:in_slash] && char == SLASH_START
        @pointer -= 1
        result << convert_slash
      elsif char == COMMENT_START
        @pointer -= 1
        result << convert_comment
      elsif char == CONTENT_END || (@brace_name && char == BRACE_END) || (@bracket_name && char == BRACKET_END) || (@slash_name && char == SLASH_END)
        @pointer -= 1
        break
      else
        @pointer -= 1
        result << convert_text(option)
      end
    end
    result.strip! if option[:trim]
    return result
  end

  def convert_tag
    unless @source[@pointer += 1] == TAG_START
      raise ZenithalParseError.new
    end
    tag_name, option = parse_tag_name
    skip_spaces
    attributes = {}
    content = nil
    char = @source[@pointer += 1]
    if char == ATTRIBUTE_START
      @pointer -= 1
      attributes = parse_attributes
      skip_spaces
      char = @source[@pointer += 1]
    end
    if char == CONTENT_START
      content = convert(option)
      unless @source[@pointer += 1] == CONTENT_END
        raise ZenithalParseError.new
      end
    elsif char == CONTENT_END
      content = nil
    else
      raise ZenithalParseError.new
    end
    result = ""
    if option[:processing]
      result << create_processing(tag_name, attributes, content)
      if tag_name == SYSTEM_PROCESSING_NAME
        skip_spaces
      end
    else
      result << create_tag(tag_name, attributes, content)
    end
    return result
  end

  def parse_tag_name
    result = ""
    option = {}
    while (char = @source[@pointer += 1]) != nil
      if char == ATTRIBUTE_START || char == CONTENT_START || char == CONTENT_END || char =~ /\s/
        @pointer -= 1
        break
      else
        result << char
      end
    end
    if result[-1] == "?"
      result.slice!(-1)
      option[:processing] = true
    elsif result[-1] == "!"
      result.slice!(-1)
      option[:trim] = true
      if result[-1] == "!"
        result.slice!(-1)
        option[:hard_trim] = true
      end
    end
    return [result, option]
  end

  def create_tag(tag_name, attributes, content)
    result = ""
    result << "<#{tag_name}"
    attributes.each do |key, value|
      result << " #{key}=\"#{value}\""
    end
    if content
      result << ">"
      result << content
      result << "</#{tag_name}>"
    else
      result << "/>"
    end
    return result
  end

  def create_processing(tag_name, attributes, content)
    result = ""
    if tag_name == SYSTEM_PROCESSING_NAME
      @version = attributes["version"]
      @brace_name = attributes["brace"]
      @bracket_name = attributes["bracket"]
      @slash_name = attributes["slash"]
    else
      result << "<?#{tag_name}"
      attributes.each do |key, value|
        result << " #{key}=\"#{value}\""
      end
      if content
        result << " #{content}"
      end
      result << "?>"
    end
    return result
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
    result = ""
    while (char = @source[@pointer += 1]) != nil
      if char == ATTRIBUTE_EQUAL || char =~ /\s/
        @pointer -= 1
        break
      else
        result << char
      end
    end
    return result
  end

  def parse_attribute_value
    unless @source[@pointer += 1] == ATTRIBUTE_VALUE_START
      raise ZenithalParseError.new
    end
    result = ""
    while (char = @source[@pointer += 1]) != nil
      if char == ATTRIBUTE_VALUE_END
        break
      else
        result << char
      end
    end
    return result
  end

  def convert_brace
    unless @source[@pointer += 1] == BRACE_START
      raise ZenithalParseError.new
    end
    content = convert
    unless @source[@pointer += 1] == BRACE_END
      raise ZenithalParseError.new
    end
    result = ""
    result << "<#{@brace_name}>"
    result << content
    result << "</#{@brace_name}>"
    return result
  end

  def convert_bracket
    unless @source[@pointer += 1] == BRACKET_START
      raise ZenithalParseError.new
    end
    content = convert
    unless @source[@pointer += 1] == BRACKET_END
      raise ZenithalParseError.new
    end
    result = ""
    result << "<#{@bracket_name}>"
    result << content
    result << "</#{@bracket_name}>"
    return result
  end

  def convert_slash
    unless @source[@pointer += 1] == SLASH_START
      raise ZenithalParseError.new
    end
    content = convert({:in_slash => true})
    unless @source[@pointer += 1] == SLASH_END
      raise ZenithalParseError.new
    end
    result = ""
    result << "<#{@slash_name}>"
    result << content
    result << "</#{@slash_name}>"
    return result
  end

  def convert_comment
    unless @source[@pointer += 1] == COMMENT_START
      raise ZenithalParseError.new
    end
    result = "<!--"
    while (char = @source[@pointer += 1]) != nil
      if char == "\n"
        @pointer -= 1
        break
      else
        result << char
      end
    end
    result << " -->"
    return result
  end

  def convert_text(option = {})
    result = ""
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
        result << convert_entity
      else
        if option[:hard_trim]
          if char =~ /\s/
            space << char
          else
            result << space unless space.include?("\n")
            space = ""
            result << char
          end
        else
          result << char
        end
      end
    end
    return result
  end

  def convert_entity
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