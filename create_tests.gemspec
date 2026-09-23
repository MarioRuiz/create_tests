require_relative "lib/create-tests/version"

Gem::Specification.new do |s|
  s.name        = 'create_tests'
  s.version     = CreateTests::VERSION
  s.summary     = "CreateTests -- Create Tests automatically from a Requests file. Perfect to be used with the result from importing a Swagger file using the open_api_import gem"
  s.description = "CreateTests -- Create Tests automatically from a Requests file. Perfect to be used with the result from importing a Swagger file using the open_api_import gem"
  s.authors     = ["Mario Ruiz"]
  s.email       = 'marioruizs@gmail.com'
  s.files       = ["lib/create_tests.rb", "lib/create-tests/version.rb", "lib/create-tests/create_helper.rb", "lib/create-tests/create_settings.rb",
    "lib/create-tests/create_test.rb", "lib/create-tests/from.rb", "lib/create-tests/get_modules.rb",
    "lib/create-tests/resource_chain.rb", "LICENSE","README.md",".yardopts"]
  s.extra_rdoc_files = ["LICENSE","README.md"]
  s.homepage    = 'https://github.com/MarioRuiz/create_tests'
  s.license       = 'MIT'
  s.add_runtime_dependency 'rufo', '~> 0.16'
  s.add_runtime_dependency 'nice_hash', '~> 1.19'
  s.add_development_dependency 'rspec', '~> 3.8', '>= 3.8.0'
  s.add_development_dependency 'simplecov', '~> 0.22'
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]
  s.executables << 'create_tests'
  s.required_ruby_version = '>= 3.0'
  s.metadata = {
    "changelog_uri" => "https://github.com/MarioRuiz/create_tests/blob/master/CHANGELOG.md",
    "source_code_uri" => "https://github.com/MarioRuiz/create_tests",
    "bug_tracker_uri" => "https://github.com/MarioRuiz/create_tests/issues",
  }
  s.post_install_message = "Thanks for installing! Visit us on https://github.com/MarioRuiz/create_tests"
end

