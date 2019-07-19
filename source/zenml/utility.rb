# coding: utf-8


require 'rexml/document'
include REXML


class Element

  alias old_get_index []
  alias old_set_index []=

  def [](key)
    if key.is_a?(String)
      return attribute(key).to_s
    else
      return old_get_index(key)
    end
  end

  def []=(key, value)
    if key.is_a?(String)
      return add_attribute(key, value)
    else
      return old_set_index(key)
    end
  end

  def each_xpath(*args, &block)
    if block
      XPath.each(self, *args) do |element|
        block.call(element)
      end
    else
      enumerator = Enumerator.new do |yielder|
        XPath.each(self, *args) do |element|
          yielder << element
        end
      end
      return enumerator
    end
  end

  def self.build(name, &block)
    element = Element.new(name)
    block.call(element)
    return element
  end

end


class Parent

  alias old_push <<

  def <<(object)
    if object.is_a?(Nodes)
      object.each do |child|
        old_push(child)
      end
    else
      old_push(object)
    end
  end

end


class Nodes < Array

  alias old_push <<

  def <<(object)
    if object.is_a?(Nodes)
      object.each do |child|
        old_push(child)
      end
    else
      old_push(object)
    end
  end

  def +(other)
    return Nodes.new(super(other))
  end

end


class String

  def ~
    return Text.new(self, true, nil, true)
  end

end