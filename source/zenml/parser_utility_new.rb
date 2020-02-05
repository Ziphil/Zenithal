# coding: utf-8


class Parser

  ERROR_TAG = Object.new

  def initialize(source)
    @source = (source.is_a?(StringReader)) ? source : StringReader.new(source.to_s)
  end

  def parse
    value = Parser.exec(->{parse_whole})
    return value
  end

  private

  # Parses a whole data.
  # This method is intended to be overridden in subclasses.
  def parse_whole
    parse_none
  end

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
        message = "Expected '#{query}'"
      when Regexp
        predicate = query =~ char
        message = "Expected /#{query}/"
      when Integer
        predicate = query == char.ord
        message = "Expected '#{query.chr}'"
      when Range
        predicate = query.cover?(char.ord)
        message = "Expected '#{query.begin}'..'#{query.end}'"
      when NilClass
        predicate = true
        message = ""
      end
      unless predicate
        error(error_message(message))
      end
    else
      error(error_message("Unexpected end of file"))
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
    char = choose(parsers)
    return char
  end

  # Parses a single character other than the specified characters.
  # If the next character coincides with any of the elements of the arguments, then an error occurs and no input is consumed.
  # Otherwise, a string which consists of the next single chracter is returned.
  def parse_char_out(chars)
    char = @source.peak
    unless char && chars.all?{|s| s != char}
      message = "Expected other than " + chars.map{|s| "'#{s}'"}.join(", ")
      error(error_message(message))
    end
    char = @source.read
    return char
  end

  def parse_eof
    char = @source.peak
    unless char == nil
      error(error_message("Document ends before reaching end of file"))
    end
    char = @source.read
    return true
  end

  # Parses nothing; thus an error always occur.
  def parse_none
    error(error_message("This cannot happen"))
    return nil
  end

  # Simply executes the specified parser, but additionally performs backtracking on error.
  # If an error occurs in executing the parser, this method rewinds the state of the input to that before executing, and then raises an error.
  # Otherwise, a result obtained by the parser is returned.
  def try(parser)
    mark = @source.mark
    value = nil
    message = catch(ERROR_TAG) do
      value = parser.call
    end
    unless value
      @source.reset(mark)
      error(message)
    end
    return value
  end

  # First this method executes the first specified parser.
  # If it fails without consuming any input, then this method trys the next specified parser and repeats this procedure.
  def choose(*parsers)
    value, message = nil, ""
    parsers.each do |parser|
      mark = @source.mark
      message = catch(ERROR_TAG) do
        value = parser.call
      end
      if value
        break
      elsif mark != @source.mark
        break
      end
    end
    unless value
      error(message)
    end
    return value
  end

  def many(parser, lower_limit = 0, upper_limit = nil)
    values, count = [], 0
    loop do
      mark = @source.mark
      value = parser.call
      if value
        values << value
        count += 1
        if upper_limit && count >= upper_limit
          break
        end
      else
        @source.reset(mark)
        break
      end
    end
    unless count >= lower_limit
      error(error_message("Less match"))
    end
    return values
  end

  def maybe(parser)
    value = self.many(parser, 0, 1).first
    return value
  end

  # Raises a parse error.
  # Do not use the standard exception mechanism during parsing, and always use this method to avoid creating a unnecessary stacktrace.
  def error(message)
    throw(ERROR_TAG, message)
  end

  def error_message(message)
    return "[line #{@source.lineno}] #{message}"
  end

  def self.exec(parser)
    value = nil
    message = catch(ERROR_TAG) do
      value = parser.call
    end
    unless value
      raise ZenithalParseError.new(message)
    end
    return value
  end

end