require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/example/'
  track_files 'lib/**/*.rb'
  enable_coverage :branch
end

require 'create_tests'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run_when_matching :focus
  config.order = :random
end
