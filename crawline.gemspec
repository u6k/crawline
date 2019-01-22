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
  spec.description   = %q{u6k crawler's framework.}
  spec.homepage      = "https://github.com/u6k/crawline"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  #if spec.respond_to?(:metadata)
  #  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  #else
  #  raise "RubyGems 2.0 or newer is required to protect against " \
  #    "public gem pushes."
  #end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'webmock', '~> 3.5', '>= 3.5.1'

  spec.add_dependency 'aws-sdk-s3', '~> 1.30', '>= 1.30.1'
  spec.add_dependency 'seven_zip_ruby', '~> 1.2', '>= 1.2.5'
end
