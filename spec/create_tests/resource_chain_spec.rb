require 'spec_helper'

RSpec.describe CreateTests, '#extract_resource_chain' do
  def extract(request, params)
    chain, target = CreateTests.send(:extract_resource_chain, request, params)
    return chain, target
  end

  def chain_only(request, params)
    chain, _target = extract(request, params)
    chain
  end

  it 'returns empty chain and nil target when path has no param slots' do
    request = { path: "/providers/Microsoft.NetApp/operations?api-version=2019", method: :get }
    chain, target = extract(request, [])
    expect(chain).to eq([])
    expect(target).to be_nil
  end

  it 'returns empty chain and nil target when only one resource/param pair exists' do
    request = { path: "/subscriptions//providers?api-version=2019", method: :get }
    chain, target = extract(request, ["@subscription_id"])
    expect(chain).to eq([])
    expect(target).to be_nil
  end

  it 'returns empty chain and nil target when request has no path key' do
    request = { method: :get }
    chain, target = extract(request, [])
    expect(chain).to eq([])
    expect(target).to be_nil
  end

  it 'returns empty chain and nil target when fewer than 2 params' do
    request = { path: "/items/1", method: :get }
    chain, target = extract(request, ["@id"])
    expect(chain).to eq([])
    expect(target).to be_nil
  end

  it 'skips subscriptions and resource_groups; sole real resource is the target' do
    request = {
      path: "/subscriptions//resourceGroups//providers/Microsoft.NetApp/netAppAccounts//?api-version=2019",
      method: :get
    }
    params = ["@subscription_id", "@resource_group_name", "@account_name"]
    chain, target = extract(request, params)
    expect(chain).to eq([])
    expect(target[:resource]).to eq("net_app_accounts")
    expect(target[:params_up_to]).to eq(["@subscription_id", "@resource_group_name", "@account_name"])
  end

  it 'extracts real-resource prerequisites from deep interpolated path' do
    request = {
      path: "/subscriptions//resourceGroups//providers/Microsoft.NetApp/netAppAccounts//capacityPools//volumes/?api-version=2019",
      method: :put
    }
    params = ["@subscription_id", "@resource_group_name", "@account_name", "@pool_name", "@volume_name"]
    chain, target = extract(request, params)
    expect(chain.size).to eq(2)
    resources = chain.map { |r| r[:resource] }
    expect(resources).to eq(["net_app_accounts", "capacity_pools"])
    expect(target[:resource]).to eq("volumes")
  end

  it 'keeps infra params in params_up_to for real resources' do
    request = {
      path: "/subscriptions//resourceGroups//providers/Microsoft.NetApp/netAppAccounts//capacityPools//?api-version=2019",
      method: :put
    }
    params = ["@subscription_id", "@resource_group_name", "@account_name", "@pool_name"]
    chain, target = extract(request, params)

    expect(chain.size).to eq(1)
    expect(chain[0][:resource]).to eq("net_app_accounts")
    expect(chain[0][:params_up_to]).to eq(["@subscription_id", "@resource_group_name", "@account_name"])
    expect(target[:resource]).to eq("capacity_pools")
    expect(target[:params_up_to]).to eq(["@subscription_id", "@resource_group_name", "@account_name", "@pool_name"])
  end

  it 'target includes all params up to its level' do
    request = {
      path: "/subscriptions//resourceGroups//providers/Microsoft.NetApp/netAppAccounts//?api-version=2019",
      method: :delete
    }
    params = ["@subscription_id", "@resource_group_name", "@account_name"]
    _chain, target = extract(request, params)
    expect(target[:params_up_to]).to eq(["@subscription_id", "@resource_group_name", "@account_name"])
  end

  it 'skips infra segments in placeholder-style paths' do
    request = {
      path: "/subscriptions/{sub}/resourceGroups/{rg}/accounts/{acct}?v=1",
      method: :get
    }
    params = ["@sub", "@rg", "@acct"]
    chain, target = extract(request, params)
    expect(chain).to eq([])
    expect(target[:resource]).to eq("accounts")
    expect(target[:params_up_to]).to eq(["@sub", "@rg", "@acct"])
  end

  it 'skips providers when it appears as a resource pair' do
    request = {
      path: "/subscriptions/{sub}/providers/{provider}/accounts/{acct}",
      method: :get
    }
    params = ["@sub", "@provider", "@acct"]
    chain, target = extract(request, params)
    expect(chain).to eq([])
    expect(target[:resource]).to eq("accounts")
    expect(target[:params_up_to]).to eq(["@sub", "@provider", "@acct"])
  end

  it 'converts camelCase resource names to snake_case' do
    request = {
      path: "/a//capacityPools//volumes/?v=1",
      method: :get
    }
    params = ["@x", "@pool", "@vol"]
    chain = chain_only(request, params)
    resources = chain.map { |r| r[:resource] }
    expect(resources).to include("capacity_pools")
  end

  it 'strips query string before parsing' do
    request = {
      path: "/a//b/?api-version=2019&foo=bar",
      method: :get
    }
    params = ["@x", "@y"]
    chain = chain_only(request, params)
    expect(chain.size).to eq(1)
    expect(chain[0][:resource]).to eq("a")
  end

  it 'handles Uber-style paths with inline params (no hierarchy)' do
    request = {
      path: "/v1/products?latitude=0&longitude=0&",
      method: :get
    }
    chain, target = extract(request, ["@latitude", "@longitude"])
    expect(chain).to eq([])
    expect(target).to be_nil
  end
end

RSpec.describe CreateTests, '#to_snake_case' do
  it 'converts camelCase' do
    expect(CreateTests.send(:to_snake_case, "capacityPools")).to eq("capacity_pools")
  end

  it 'converts PascalCase' do
    expect(CreateTests.send(:to_snake_case, "NetAppAccounts")).to eq("net_app_accounts")
  end

  it 'leaves already snake_case unchanged' do
    expect(CreateTests.send(:to_snake_case, "resource_groups")).to eq("resource_groups")
  end

  it 'handles all lowercase' do
    expect(CreateTests.send(:to_snake_case, "volumes")).to eq("volumes")
  end
end
