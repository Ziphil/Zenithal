# coding: utf-8


class ZenithalParseError < StandardError

  def initialize(reader, message = "")
    whole_message = "[line #{reader.lineno}] #{message}"
    super(whole_message)
  end

end