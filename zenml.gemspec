# coding: utf-8


lib = File.expand_path("../lib", __FILE__)
unless $LOAD_PATH.include?(lib)
  $LOAD_PATH.unshift(lib) 
end

Gem::Specification.new do |spec|
  spec.name = "zenml"
  spec.version = "1.2.1"
  spec.authors = ["Ziphil"]
  spec.email = ["ziphil.shaleiras@gmail.com"]
  spec.licenses = ["MIT"]
  spec.homepage = "https://github.com/Ziphil/Zenithal"
  spec.summary = "Alternative syntax for XML"
  spec.description = <<~end_string
    This gem serves a tool for parsing a document written in ZenML, an alternative new syntax for XML, to an XML node tree.
    This also contains some utility classes to transform XML documents.
  end_string
  spec.required_ruby_version = ">= 2.5"

  spec.files = Dir.glob("source/**/*.rb")
  spec.require_paths = ["source"]
end