require 'spec_helper'

RSpec.describe CreateTests, '#create_helper' do
  before(:each) do
    CreateTests.instance_variable_set(:@logger, Logger.new(nil))
  end

  it 'generates a Helper module with methods for each parameter' do
    output = CreateTests.send(:create_helper, ["@latitude", "@longitude"], "")
    expect(output).to include("module Helper")
    expect(output).to include("def self.latitude(")
    expect(output).to include("def self.longitude(")
    expect(output).to include("return ''")
  end

  it 'generates require_relative to settings in new helper' do
    output = CreateTests.send(:create_helper, [], "")
    expect(output).to include("require_relative '../settings/general'")
  end

  it 'does not require setup or cleanup files unless a chain is generated' do
    output = CreateTests.send(:create_helper, [], "")
    expect(output).not_to include("helper/setup")
    expect(output).not_to include("helper/cleanup")
  end

  it 'requires setup and cleanup when chain paths are provided' do
    output = CreateTests.send(:create_helper, [], "", chain_requires: ["../helper/setup", "../helper/cleanup"])
    expect(output).to include("require_relative '../helper/setup'")
    expect(output).to include("require_relative '../helper/cleanup'")
  end

  it 'inserts missing chain requires into an existing helper' do
    existing = "module Helper\ndef self.latitude(http = NiceHttp.new())\nreturn ''\nend\nend"
    output = CreateTests.send(:create_helper, ["@latitude"], existing, chain_requires: ["../helper/setup", "../helper/cleanup"])
    expect(output).to include("require_relative '../helper/setup'")
    expect(output).to include("require_relative '../helper/cleanup'")
    expect(output.scan("def self.latitude(").size).to eq(1)
  end

  it 'uses custom settings path when provided' do
    output = CreateTests.send(:create_helper, [], "", settings_relative_path: '../config/general')
    expect(output).to include("require_relative '../config/general'")
  end

  it 'appends new methods to existing helper text without duplicating' do
    existing = "module Helper\ndef self.latitude(http = NiceHttp.new())\nreturn ''\nend\nend"
    output = CreateTests.send(:create_helper, ["@latitude", "@longitude"], existing)
    expect(output.scan("def self.latitude(").size).to eq(1)
    expect(output).to include("def self.longitude(")
  end

  it 'does not duplicate methods that already exist' do
    existing = "module Helper\ndef self.latitude(http = NiceHttp.new())\nreturn ''\nend\n\ndef self.longitude(http = NiceHttp.new())\nreturn ''\nend\nend"
    output = CreateTests.send(:create_helper, ["@latitude", "@longitude"], existing)
    expect(output.scan("def self.latitude(").size).to eq(1)
    expect(output.scan("def self.longitude(").size).to eq(1)
  end

  it 'handles empty params list' do
    output = CreateTests.send(:create_helper, [], "")
    expect(output).to include("module Helper")
  end

  it 'does not contain setup/cleanup methods (those are in separate files)' do
    output = CreateTests.send(:create_helper, ["@name"], "")
    expect(output).not_to include("def self.setup_")
    expect(output).not_to include("def self.cleanup_")
  end
end

RSpec.describe CreateTests, '#create_setup_file' do
  let(:resources) do
    [
      { resource: "subscriptions", param: "subscription_id", params_up_to: ["@subscription_id"] },
      { resource: "net_app_accounts", param: "account_name", params_up_to: ["@subscription_id", "@resource_group_name", "@account_name"] },
      { resource: "capacity_pools", param: "pool_name", params_up_to: ["@subscription_id", "@resource_group_name", "@account_name", "@pool_name"] },
    ]
  end

  before(:each) do
    CreateTests.instance_variable_set(:@logger, Logger.new(nil))
  end

  it 'generates setup methods for each resource' do
    output = CreateTests.send(:create_setup_file, resources)
    expect(output).to include("def self.setup_subscriptions(http, subscription_id)")
    expect(output).to include("def self.setup_net_app_accounts(http, subscription_id, resource_group_name, account_name)")
    expect(output).to include("def self.setup_capacity_pools(http, subscription_id, resource_group_name, account_name, pool_name)")
  end

  it 'includes cascading parent calls in each setup method' do
    output = CreateTests.send(:create_setup_file, resources)
    expect(output).to include("setup_subscriptions(http, subscription_id)")
    expect(output).to include("setup_net_app_accounts(http, subscription_id, resource_group_name, account_name)")
  end

  it 'first resource has no parent call' do
    output = CreateTests.send(:create_setup_file, resources)
    sub_start = output.index("def self.setup_subscriptions")
    sub_end = output.index("def self.setup_net_app_accounts")
    subscriptions_body = output[(sub_start + "def self.setup_subscriptions".length)..sub_end]
    expect(subscriptions_body).not_to match(/\bsetup_\w+\(/)
  end

  it 'includes TODO comments' do
    output = CreateTests.send(:create_setup_file, resources)
    expect(output).to include("# TODO: Create the subscriptions resource")
    expect(output).to include("# TODO: Create the capacity_pools resource")
  end

  it 'wraps methods in module Helper' do
    output = CreateTests.send(:create_setup_file, resources)
    expect(output).to include("module Helper\n")
    expect(output.strip).to end_with("end")
  end

  it 'returns OpenStruct with state Succeeded by default' do
    output = CreateTests.send(:create_setup_file, resources)
    expect(output).to include("require 'ostruct'")
    expect(output).to include("OpenStruct.new(state: 'Succeeded')")
  end

  it 'deduplicates resources' do
    duplicated = resources + resources
    output = CreateTests.send(:create_setup_file, duplicated)
    expect(output.scan("def self.setup_subscriptions(").size).to eq(1)
  end

  it 'returns minimal output for empty resources' do
    output = CreateTests.send(:create_setup_file, [])
    expect(output).to include("module Helper")
    expect(output).not_to include("def self.setup_")
  end
end

RSpec.describe CreateTests, '#create_cleanup_file' do
  let(:resources) do
    [
      { resource: "subscriptions", param: "subscription_id", params_up_to: ["@subscription_id"] },
      { resource: "net_app_accounts", param: "account_name", params_up_to: ["@subscription_id", "@resource_group_name", "@account_name"] },
      { resource: "capacity_pools", param: "pool_name", params_up_to: ["@subscription_id", "@resource_group_name", "@account_name", "@pool_name"] },
    ]
  end

  before(:each) do
    CreateTests.instance_variable_set(:@logger, Logger.new(nil))
  end

  it 'generates cleanup methods for each resource' do
    output = CreateTests.send(:create_cleanup_file, resources)
    expect(output).to include("def self.cleanup_subscriptions(http, subscription_id)")
    expect(output).to include("def self.cleanup_net_app_accounts(http, subscription_id, resource_group_name, account_name)")
    expect(output).to include("def self.cleanup_capacity_pools(http, subscription_id, resource_group_name, account_name, pool_name)")
  end

  it 'includes cascading parent cleanup calls (delete self then call parent)' do
    output = CreateTests.send(:create_cleanup_file, resources)
    pools_section = output[output.index("def self.cleanup_capacity_pools")..] || ""
    expect(pools_section).to include("cleanup_net_app_accounts(http, subscription_id, resource_group_name, account_name)")
  end

  it 'first resource has no parent cleanup call' do
    output = CreateTests.send(:create_cleanup_file, resources)
    sub_start = output.index("def self.cleanup_subscriptions")
    sub_end = output.index("def self.cleanup_net_app_accounts") || output.length
    subscriptions_body = output[(sub_start + "def self.cleanup_subscriptions".length)..sub_end]
    expect(subscriptions_body).not_to match(/\bcleanup_\w+\(/)
  end

  it 'includes TODO comments' do
    output = CreateTests.send(:create_cleanup_file, resources)
    expect(output).to include("# TODO: Delete the subscriptions resource")
    expect(output).to include("# TODO: Delete the capacity_pools resource")
  end

  it 'deduplicates resources' do
    duplicated = resources + resources
    output = CreateTests.send(:create_cleanup_file, duplicated)
    expect(output.scan("def self.cleanup_subscriptions(").size).to eq(1)
  end
end
