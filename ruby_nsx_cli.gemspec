
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ruby_nsx_cli/version"

Gem::Specification.new do |spec|
  spec.name          = "ruby_nsx_cli"
  spec.version       = RubyNsxCli::VERSION
  spec.authors       = ["Daniel Cole"]
  spec.email         = ["dannycole12@gmail.com"]

  spec.summary       = %q{UNDER DEVELOPMENT: Simple Ruby VMWare NSX API Client to create and interact with NSX objects}
  spec.homepage      = "https://github.com/daniel-cole"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 12.0.0"
  spec.add_development_dependency 'rest-client', '2.0.2'
  spec.add_development_dependency 'nokogiri', '1.8.1'
  spec.add_development_dependency 'minitest', '5.10.1'
end
