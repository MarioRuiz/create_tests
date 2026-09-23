require 'spec_helper'

RSpec.describe CreateTests, '#create_settings' do
  it 'includes required library requires' do
    output = CreateTests.send(:create_settings, "./requests/api.rb", [])
    expect(output).to include("require 'nice_http'")
    expect(output).to include("require 'nice_hash'")
    expect(output).to include("require 'string_pattern'")
    expect(output).to include("require 'pathname'")
  end

  it 'includes the requests file require_relative' do
    output = CreateTests.send(:create_settings, "../requests/api.rb", [])
    expect(output).to include("require_relative '../requests/api.rb'")
  end

  it 'includes the helper require_relative with default path' do
    output = CreateTests.send(:create_settings, "./requests/api.rb", [])
    expect(output).to include("require_relative '../spec/helper.rb'")
  end

  it 'uses custom helper path when provided' do
    output = CreateTests.send(:create_settings, "./requests/api.rb", [], helper_relative_path: '../test/helper.rb')
    expect(output).to include("require_relative '../test/helper.rb'")
  end

  it 'includes module include statements' do
    mods = ["Swagger::UberApi::V1_0_0"]
    output = CreateTests.send(:create_settings, "./requests/api.rb", mods)
    expect(output).to include("include Swagger::UberApi::V1_0_0")
  end

  it 'includes NiceHttp configuration' do
    output = CreateTests.send(:create_settings, "./requests/api.rb", [])
    expect(output).to include("NiceHttp.host = ENV['HOST']")
    expect(output).to include("NiceHttp.log = :file_run")
  end

  it 'has correct Authentication header (not Auhentication)' do
    output = CreateTests.send(:create_settings, "./requests/api.rb", [])
    expect(output).to include("Authentication:")
    expect(output).not_to include("Auhentication:")
  end

  it 'includes ROOT_DIR definition' do
    output = CreateTests.send(:create_settings, "./requests/api.rb", [])
    expect(output).to include("ROOT_DIR = Pathname.new(__FILE__)")
  end
end
