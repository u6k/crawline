# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'crawline/version'

Gem::Specification.new do |spec|
  spec.name          = "crawline"
  spec.version       = Crawline::VERSION
  spec.authors       = ["u6k"]
  spec.email         = ["u6k.apps@gmail.com"]

  spec.summary       = %q{u6k crawler's framework.}
  spec.homepage      = "https://github.com/u6k/crawline"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'webmock', '~> 3.5', '>= 3.5.1'
  spec.add_development_dependency 'nokogiri', '~> 1.6', '>= 1.6.8'
  spec.add_development_dependency 'yard', '~> 0.9.18'
  spec.add_development_dependency 'timecop', '~> 0.9.1'

  spec.add_dependency 'aws-sdk-s3', '~> 1.30', '>= 1.30.1'
  spec.add_dependency 'seven_zip_ruby', '~> 1.2', '>= 1.2.5'
end
