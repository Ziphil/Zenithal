# coding: utf-8


class StringReader

  attr_reader :lineno

  def initialize(string)
    @string = string.chars
    @pos = -1
    @lineno = 1
    @marked_pos = nil
    @marked_lineno = nil
  end

  def read
    @pos += 1
    char = @string[@pos]
    if char == "\n"
      @lineno += 1
    end
    return char
  end

  def peek
    char = @string[@pos + 1]
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

  def mark
    @marked_pos = @pos
    @marked_lineno = @lineno
  end

  def reset
    @pos = @marked_pos
    @lineno = @marked_lineno
  end

end