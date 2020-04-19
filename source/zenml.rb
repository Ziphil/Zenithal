# coding: utf-8


module Zenithal

  VERSION = "1.6.0"
  VERSION_ARRAY = VERSION.split(/\./).map(&:to_i)

end


require 'rexml/document'

require 'zenml/error'
require 'zenml/reader'
require 'zenml/parser_utility'
require 'zenml/parser'
require 'zenml/converter'
require 'zenml/utility'