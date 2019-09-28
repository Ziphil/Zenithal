# coding: utf-8


class Parser

  attr_reader :builder

  def initialize(builder, &method)
    @builder = builder
    @method = method
  end

  def self.build(source, &block)
    parser = Parser.new(source) do
      value = nil
      message = catch(:error) do
        value = block.call
      end
      if value
        next Result.success(value)
      else
        next Result.error(message)
      end
    end
    return parser
  end

  def exec
    return @builder.instance_eval(&@method)
  end

  def !
    result = self.exec
    if result.success?
      return result.value
    else
      throw(:error, result.message)
    end
  end

  def |(other)
    this = self
    if this.builder.equal?(other.builder)
      parser = Parser.new(this.builder) do
        mark = source.mark
        result = this.exec
        if result.success?
          next result
        else
          source.reset(mark)
          result = other.exec
          next result
        end
      end
      return parser
    else
      raise StandardError.new("Different source")
    end
  end

  def many(lower_limit = 0, upper_limit = nil)
    this = self
    parser = Parser.new(this.builder) do
      values, count = [], 0
      loop do
        mark = source.mark
        each_result = this.exec
        if each_result.success?
          values << each_result.value
          count += 1
          if upper_limit && count >= upper_limit
            break
          end
        else
          source.reset(mark)
          break
        end
      end
      if count >= lower_limit
        next Result.success(values)
      else
        next Result.error("")
      end
    end
    return parser
  end

  def maybe
    return self.many(0, 1).map{|s| s.first}
  end

  def map(&block)
    this = self
    parser = Parser.new(this.builder) do
      result = this.exec
      if result.success?
        next Result.success(block.call(result.value))
      else
        next result
      end
    end
    return parser
  end

end


module CommonParserMethod

  private

  # Parses a single character which matches the specified query.
  # If the next character does not match the query or the end of file is reached, an error result is returned.
  # Otherwise, a success result with a string containing the matched chracter is returned.
  def parse_char(query)
    parser = Parser.new(self) do
      char = source.read
      unless char == nil
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
        end
        if predicate
          next Result.success(char)
        else
          next Result.error(error_message(message))
        end
      else
        next Result.error(error_message("Unexpected end of file"))
      end
    end
    return parser
  end

  # Parses a single character which matches any of the specified queries.
  def parse_char_any(queries)
    return queries.map{|s| parse_char(s)}.inject(:|)
  end

  # Parses a single character other than the specified characters.
  # If the next character coincides with any of the elements of the arguments, an error result is returned.
  # Otherwise, a success result with a string containing the next chracter is returned.
  def parse_char_out(chars)
    parser = Parser.new(self) do
      char = source.read
      if char && chars.all?{|s| s != char}
        next Result.success(char)
      else
        message = "Expected other than " + chars.map{|s| "'#{s}'"}.join(", ")
        next Result.error(error_message(message))
      end
    end
    return parser
  end

  def parse_eof
    parser = Parser.new(self) do
      char = source.read
      if char == nil
        next Result.success(true)
      else
        next Result.error(error_message("Document ends before reaching end of file"))
      end
    end
    return parser
  end

  # Returns a parser which always fails.
  # That is, it always returns an error result.
  def parse_none
    parser = Parser.new(self) do
      next Result.error(error_message("This cannot happen"))
    end
    return parser
  end

end


class Result

  attr_reader :value
  attr_reader :message

  def initialize(value, message)
    @value = value
    @message = message
  end
  
  def self.success(value)
    return Result.new(value, nil)
  end

  def self.error(message)
    return Result.new(nil, message)
  end

  def value=(value)
    if self.success?
      @value = value
    end
  end

  def success?
    return !@message
  end

  def error?
    return !!@message
  end

end