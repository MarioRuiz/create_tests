require 'spec_helper'

RSpec.describe CreateTests do
  it 'has a VERSION constant' do
    load File.expand_path('../../lib/create-tests/version.rb', __dir__)
    expect(CreateTests::VERSION).not_to be_nil
  end

  it 'VERSION follows semantic versioning format' do
    expect(CreateTests::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
