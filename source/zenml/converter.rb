# coding: utf-8


require 'pp'
require 'rexml/document'
include REXML


class Zenithal::ZenithalConverter

  attr_reader :configs

  def initialize(document, type = :node)
    @document = document
    @type = type
    @configs = {}
    @templates = {}
    @functions = {}
    @default_element_template = lambda{|s| (@type == :text) ? "" : Nodes[]}
    @default_text_template = lambda{|s| (@type == :text) ? "" : Nodes[]}
  end

  def convert(initial_scope = "")
    document = nil
    if @type == :text
      document = convert_element(@document.root, initial_scope)
    else
      document = Document.new
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
    nodes = (@type == :text) ? "" : Nodes[]
    element.children.each do |child|
      case child
      when Element
        result_nodes = convert_element(child, scope, *args)
        if result_nodes
          nodes << result_nodes
        end
      when Text
        result_nodes = convert_text(child, scope, *args)
        if result_nodes
          nodes << result_nodes
        end
      end
    end
    return nodes
  end

  def apply_select(element, xpath, scope, *args)
    nodes = (@type == :text) ? "" : Nodes[]
    element.each_xpath(xpath) do |child|
      case child
      when Element
        result_nodes = convert_element(child, scope, *args)
        if result_nodes
          nodes << result_nodes
        end
      when Text
        result_nodes = convert_text(child, scope, *args)
        if result_nodes
          nodes << result_nodes
        end
      end
    end
    return nodes
  end

  def call(element, name, *args)
    nodes = (@type == :text) ? "" : Nodes[]
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

end