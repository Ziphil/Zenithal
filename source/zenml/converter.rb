# coding: utf-8


class Zenithal::ZenithalConverter

  SINGLETON_NAMES = ["br", "img", "hr", "meta", "input", "embed", "area", "base", "link"]

  attr_reader :document
  attr_accessor :configs
  attr_accessor :variables
  attr_accessor :functions

  def initialize(document, type = :node)
    @document = document
    @type = type
    @configs = {}
    @variables = {}
    @templates = {}
    @functions = {}
    @default_element_template = lambda{|_| empty_nodes}
    @default_text_template = lambda{|_| empty_nodes}
    reset_variables
  end

  # Changes the document to be converted.
  # Note that this method initialises the variable hash, but not the configuration hash.
  def update(document)
    @document = document
    reset_variables
  end

  def convert(initial_scope = "")
    document = nil
    if @type == :text
      document = convert_element(@document.root, initial_scope)
    else
      document = REXML::Document.new
      children = convert_element(@document.root, initial_scope)
      children.each do |child|
        document.add(child)
      end
    end
    return document
  end

  def convert_element(element, scope, *args)
    nodes = nil
    @templates.each do |(element_pattern, scope_pattern), block|
      if element_pattern != nil && element_pattern.any?{|s| s === element.name} && scope_pattern.any?{|s| s === scope}
        nodes = instance_exec(element, scope, *args, &block)
        break
      end
    end
    return nodes || @default_element_template.call(element)
  end

  def convert_text(text, scope, *args)
    nodes = nil
    @templates.each do |(element_pattern, scope_pattern), block|
      if element_pattern == nil && scope_pattern.any?{|s| s === scope}
        nodes = instance_exec(text, scope, *args, &block)
        break
      end
    end
    return nodes || @default_text_template.call(text)
  end

  def apply(element, scope, *args)
    nodes = empty_nodes
    element.children.each do |child|
      case child
      when REXML::Element
        result_nodes = convert_element(child, scope, *args)
        if result_nodes
          nodes << result_nodes
        end
      when REXML::Text
        result_nodes = convert_text(child, scope, *args)
        if result_nodes
          nodes << result_nodes
        end
      end
    end
    return nodes
  end

  def apply_select(element, xpath, scope, *args)
    nodes = empty_nodes
    element.each_xpath(xpath) do |child|
      case child
      when REXML::Element
        result_nodes = convert_element(child, scope, *args)
        if result_nodes
          nodes << result_nodes
        end
      when REXML::Text
        result_nodes = convert_text(child, scope, *args)
        if result_nodes
          nodes << result_nodes
        end
      end
    end
    return nodes
  end

  def call(element, name, *args)
    nodes = empty_nodes
    @functions.each do |function_name, block|
      if function_name == name
        nodes = instance_exec(element, *args, &block)
        break
      end
    end
    return nodes
  end

  def add(element_pattern, scope_pattern, &block)
    @templates.store([element_pattern, scope_pattern], block)
  end

  def set(name, &block)
    @functions.store(name, block)
  end

  def add_default(element_pattern, &block)
    if element_pattern
      @default_element_template = block
    else
      @default_text_template = block
    end
  end

  def empty_nodes
    return (@type == :text) ? "" : REXML::Nodes[]
  end

  # Override this method to customise how to initialise the variable hash.
  # This method is called when creating or updating an instance.
  def reset_variables
    @variables = {}
  end

  # Returns a simple converter that converts an XML document to the equivalent HTML document.
  def self.simple_html(document)
    converter = Zenithal::ZenithalConverter.new(document, :text)
    converter.add([//], [""]) do |element|
      close = !SINGLETON_NAMES.include?(element.name)
      html = "<#{element.name}"
      element.attributes.each_attribute do |attribute|
        html << " #{attribute.name}='#{attribute.to_s}'"
      end
      html << ">"
      if close
        html << apply(element, "")
        html << "</#{element.name}>"
      end
      if element.name == "html"
        html = "<!DOCTYPE html>\n\n" + html
      end
      next html
    end
    converter.add_default(nil) do |text|
      next text.to_s
    end
    return converter
  end

end