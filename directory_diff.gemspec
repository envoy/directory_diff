# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'directory_diff/version'

Gem::Specification.new do |spec|
  spec.name          = "directory_diff"
  spec.version       = DirectoryDiff::VERSION
  spec.authors       = ["Kamal Mahyuddin"]
  spec.email         = ["kamal@envoy.com"]

  spec.summary       = %q{Envoy employee directory diffing.}
  spec.description   = %q{This microlibrary implements employee directory diffing between two versions.}
  spec.homepage      = "https://github.com/envoy/directory_diff"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
