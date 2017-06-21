# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'twilio_api_mock/version'

Gem::Specification.new do |spec|
  spec.name          = "twilio_api_mock"
  spec.version       = TwilioApiMock::VERSION
  spec.authors       = ["angel brown"]
  spec.email         = ["angelkbrown@gmail.com"]

  spec.summary       = %q{This gem mocks some basic functionality of the twilio-ruby gem. }
  spec.description   = %q{This gem mocks the twilio-ruby gem functionality of creating SMS messages (http://twilio-ruby.readthedocs.io/en/latest/usage/messages.html#sending-a-text-message) and retrieving a filtered list of SMS messages (http://twilio-ruby.readthedocs.io/en/latest/usage/messages.html#filtering-your-messages). It's designed to act as a stand-in for twilio-ruby in non-production environments.
  
  A created message is stored as a hash in Redis, and a composite index is used to enable lexicographical searching by phone number and date sent.

  The TwilioApiMock::Messages class requires a redis instance to be passed in during initialization.}

  spec.homepage      = "http://angelkbrown.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_runtime_dependency "redis"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "fakeredis"
  spec.add_development_dependency "pry"
end
