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

  def get_texts_recursive
    texts = []
    self.children.each do |child|
      case child
      when Text
        texts << child
      when Element
        texts.concat(child.get_texts_recursive)
      end
    end
    return texts
  end

  def inner_text(compress = false)
    text = XPath.match(self, ".//text()").map{|s| s.value}.join("")
    if compress
      text.gsub!(/\r/, "")
      text.gsub!(/\n\s*/, " ")
      text.gsub!(/\s+/, " ")
      text.strip!
    end
    return text
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
    return self
  end

  def +(other)
    return Nodes.new(super(other))
  end

  def trim_indents
    texts = []
    if self.last.is_a?(Text)
      self.last.value = self.last.value.rstrip
    end
    self.each do |child|
      case child
      when Text
        texts << child
      when Element
        texts.concat(child.get_texts_recursive)
      end
    end
    indent_length = Float::INFINITY
    texts.each do |text|
      text.value.scan(/\n(\x20+)/) do |match|
        indent_length = [match[0].length, indent_length].min
      end
    end
    texts.each do |text|
      text.value = text.value.gsub(/\n(\x20+)/){"\n" + " " * ($1.length - indent_length)}
    end
    if self.first.is_a?(Text)
      self.first.value = self.first.value.lstrip
    end
  end

end


class String

  def ~
    return Text.new(self, true, nil, true)
  end

end