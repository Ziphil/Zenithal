# coding: utf-8


module Parser

  def parse_char(query)
    char = self.read
    predicate, message = false, nil
    case query
    when String
      predicate = query == char
      message = "expected '#{query}'"
    when Regexp
      predicate = query =~ char
      message = "expected /#{query}/"
    when Integer
      predicate = query == char&.ord
      message = "expected '#{query.chr}'"
    when Range
      predicate = query.cover?(char&.ord)
      message = "expected '#{query.begin}'..'#{query.end}'"
    end
    if predicate
      return Result.success(char)
    else
      return Result.error(create_error_message(message))
    end
  end

  def parse_char_choice(queries)
    methods = queries.map{|s| lambda{parse_char(s)}}
    char = any(methods)
    return char
  end

  def any(methods)
    result, messages = nil, []
    mark
    methods.each do |method|
      reset
      each_result = method.call
      if each_result.success?
        result = each_result
        break
      else
        messages << each_result.message
      end
    end
    return result || Result.error(messages.join(" | "))
  end

  def many(method = nil, &block)
    method ||= block
    values = []
    loop do
      mark
      each_result = method.call
      if each_result.success?
        values << each_result.value
      else
        reset
        break
      end
    end
    return Result.success(values)
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

  def get
    if self.success?
      return @value
    else
      raise ParseError.new(@message)
    end
  end

  def |(other)
    if self.success?
      return self
    else
      return other
    end
  end

  def success?
    return !@message
  end

  def error?
    return !!@message
  end

  def self.exec(&block)
    begin
      value = block.call
      return Result.success(value)
    rescue ParseError => error
      return Result.error(error.message)
    end
  end

end


class ParseError < StandardError

  def initialize(message = "")
    super(message)
  end

end