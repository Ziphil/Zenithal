# coding: utf-8


require 'pp'
require 'rexml/document'
require_relative 'parser_utility'
include REXML


class ZenithalNewParser

  include Parser

  TAG_START = "\\"
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
  BRACE_START = "{"
  BRACE_END = "}"
  BRACKET_START = "["
  BRACKET_END = "]"
  SLASH_START = "/"
  SLASH_END = "/"
  COMMENT_DELIMITER = "#"
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

  attr_writer :brace_name
  attr_writer :bracket_name
  attr_writer :slash_name

  def initialize(source)
    @source = StringReader.new(source)
    @version = nil
    @brace_name = nil
    @bracket_name = nil
    @slash_name = nil
    @macros = {}
  end

  def parse
  end

  def parse_element
    result = Result.exec do
      ~parse_char(TAG_START)
      name = ~parse_identifier
      marks = ~parse_marks
      next name, marks
    end
    return result
  end

  def parse_marks
    return many{parse_mark}
  end
  
  def parse_mark
    methods = MARKS.map do |mark, query|
      method = lambda do
        result = parse_char(query)
        result.value = mark
        next result
      end
    end
    return any(methods)
  end

  def parse_identifier
    result = Result.exec do
      identifier = ""
      identifier.concat(~parse_first_identifier_char)
      identifier.concat(*~many{parse_middle_identifier_char})
      next identifier
    end
    return result
  end

  def parse_first_identifier_char
    return parse_char_choice(VALID_FIRST_IDENTIFIER_CHARS)
  end

  def parse_middle_identifier_char
    return parse_char_choice(VALID_MIDDLE_IDENTIFIER_CHARS)
  end

  def parse_space
    return many{parse_char_choice(SPACE_CHARS)}
  end

  def read
    return @source.read
  end

  def mark
    @source.mark
  end

  def reset
    @source.reset
  end

  def create_error_message(message)
    return "[line #{@source.lineno}] #{message}"
  end

end