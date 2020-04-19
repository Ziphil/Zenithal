# coding: utf-8


class Zenithal::StringReader

  attr_reader :string
  attr_reader :lineno
  attr_reader :columnno

  def initialize(string)
    @string = string
    @chars = string.chars
    @pos = -1
    @lineno = 1
    @columnno = 1
  end

  def read
    @pos += 1
    @columnno += 1
    char = @chars[@pos]
    if char == "\n"
      @lineno += 1
      @columnno = 1
    end
    return char
  end

  def peek
    char = @chars[@pos + 1]
    return char
  end

  def mark
    return [@pos, @lineno, @columnno]
  end

  def reset(mark)
    @pos = mark[0]
    @lineno = mark[1]
    @columnno = mark[2]
  end

end