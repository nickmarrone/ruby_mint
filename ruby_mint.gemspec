# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ruby_mint/version'

Gem::Specification.new do |spec|
  spec.name          = "ruby_mint"
  spec.version       = RubyMint::VERSION
  spec.authors       = ["Nick Marrone"]
  spec.email         = ["nickmarrone@gmail.com"]

  spec.summary       = "Retrieve your Mint.com transaction and account information."
  spec.description   = "Gem to allow you to incorporate Mint.com into your ruby applications."
  spec.homepage      = "https://github.com/nickmarrone/ruby_mint"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "mechanize", "~> 2.7"
  spec.add_dependency "json", "~> 1.8"

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "rspec", "~> 3.3"
  spec.add_development_dependency "vcr", "~> 2.9"
  spec.add_development_dependency "webmock", "~> 1.21"
end
