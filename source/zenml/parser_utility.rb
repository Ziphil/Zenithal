# coding: utf-8


class Parser

  ERROR_TAG = Object.new

  attr_reader :source

  def initialize(source)
    case source
    when StringReader
      @source = source
    when File
      @source = StringReader.new(source.read)
    else
      @source = StringReader.new(source.to_s)
    end
    @inside_run = false
  end

  def update(source)
    case source
    when StringReader
      @source = source
    when File
      @source = StringReader.new(source.read)
    else
      @source = StringReader.new(source.to_s)
    end
    @inside_run = false
  end

  def run
    value = nil
    message = catch(ERROR_TAG) do
      begin
        @inside_run = true
        value = parse
      ensure
        @inside_run = false
      end
    end
    unless value
      raise ZenithalParseError.new(message)
    end
    return value
  end

  # Parses a whole data.
  # This method is intended to be overridden in subclasses.
  def parse
    throw_custom("Not implemented")
    return nil
  end

  private

  # Parses a single character which matches the specified query.
  # If the next character does not match the query or the end of file is reached, then an error occurs and no input is consumed.
  # Otherwise, a string which consists of the matched single chracter is returned.
  def parse_char(query = nil)
    char = @source.peek
    if char
      predicate, message = false, nil
      case query
      when String
        predicate = query == char
        message = "Expected '#{query}' but got '#{char}'"
      when Regexp
        predicate = query =~ char
        message = "Expected /#{query}/ but got '#{char}'"
      when Integer
        predicate = query == char.ord
        message = "Expected '##{query}' but got '#{char}'"
      when Range
        predicate = query.cover?(char.ord)
        symbol = (query.exclude_end?) ? "..." : ".."
        message = "Expected '##{query.begin}'#{symbol}'##{query.end}' but got '#{char}'"
      when NilClass
        predicate = true
        message = ""
      end
      unless predicate
        throw_custom(error_message(message))
      end
    else
      throw_custom(error_message("Unexpected end of file"))
    end
    char = @source.read
    return char
  end

  # Parses a single character which matches any of the specified queries.
  def parse_char_any(queries)
    parsers = []
    queries.each do |query|
      parsers << ->{parse_char(query)}
    end
    char = choose(*parsers)
    return char
  end

  # Parses a single character other than the specified characters.
  # If the next character coincides with any of the elements of the arguments, then an error occurs and no input is consumed.
  # Otherwise, a string which consists of the next single chracter is returned.
  def parse_char_out(chars)
    char = @source.peek
    if char
      if chars.any?{|s| s == char}
        chars_string = chars.map{|s| "'#{s}'"}.join(", ")
        throw_custom(error_message("Expected other than #{chars_string} but got '#{char}'"))
      end
    else
      throw_custom(error_message("Unexpected end of file"))
    end
    char = @source.read
    return char
  end

  def parse_eof
    char = @source.peek
    if char
      throw_custom(error_message("Document ends before reaching end of file"))
    end
    char = @source.read
    return true
  end

  # Parses nothing; thus an error always occur.
  def parse_none
    throw_custom(error_message("This cannot happen"))
    return nil
  end

  # Simply executes the specified parser, but additionally performs backtracking on error.
  # If an error occurs in executing the parser, this method rewinds the state of the input to that before executing, and then raises an error.
  # Otherwise, a result obtained by the parser is returned.
  def try(parser)
    mark = @source.mark
    value = nil
    message = catch_custom do
      value = parser.call
    end
    unless value
      @source.reset(mark)
      throw_custom(message)
    end
    return value
  end

  # First this method executes the first specified parser.
  # If it fails without consuming any input, then this method tries the next specified parser and repeats this procedure.
  def choose(*parsers)
    value, message = nil, ""
    parsers.each do |parser|
      mark = @source.mark
      message = catch_custom do
        value = parser.call
      end
      if value
        break
      elsif mark != @source.mark
        break
      end
    end
    unless value
      throw_custom(message)
    end
    return value
  end

  def many(parser, range = 0..)
    values, message, count = [], "", 0
    lower_limit, upper_limit = range.begin, range.end
    if upper_limit && range.exclude_end?
      upper_limit -= 1
    end
    loop do
      mark = @source.mark
      value = nil
      message = catch_custom do
        value = parser.call
      end
      if value
        values << value
        count += 1
        if upper_limit && count >= upper_limit
          break
        end
      else
        if mark != @source.mark
          throw_custom(message)
        end
        break
      end
    end
    unless count >= lower_limit
      throw_custom(message)
    end
    return values
  end

  def maybe(parser)
    value = many(parser, 0..1).first
    return value
  end

  # Catch a parse error.
  # Do not use the standard exception mechanism during parsing.
  def catch_custom(&block)
    catch(ERROR_TAG, &block)
  end

  # Raises a parse error.
  # Do not use the standard exception mechanism during parsing, and always use this method to avoid creating an unnecessary stacktrace.
  def throw_custom(message)
    throw(ERROR_TAG, message)
  end

  def error_message(message)
    return "[line #{@source.lineno}, column #{@source.columnno}] #{message}"
  end

end