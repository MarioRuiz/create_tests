require 'spec_helper'

RSpec.describe CreateTests, '#get_modules' do
  before(:all) do
    # Define test module hierarchy
    module TestSwagger
      module Api
        module V1
          module Products
            def self.list; end
          end
          module Users
            def self.get_user; end
          end
        end
      end
    end

    module FlatSwagger
      module Products
        def self.list; end
      end
    end
  end

  after(:all) do
    Object.send(:remove_const, :TestSwagger)
    Object.send(:remove_const, :FlatSwagger)
  end

  it 'discovers leaf modules with no sub-constants' do
    modules = CreateTests.send(:get_modules, FlatSwagger)
    expect(modules).to include("FlatSwagger::Products")
  end

  it 'discovers deeply nested leaf modules' do
    modules = CreateTests.send(:get_modules, TestSwagger)
    expect(modules).to include("TestSwagger::Api::V1::Products")
    expect(modules).to include("TestSwagger::Api::V1::Users")
  end

  it 'finds all sibling leaf modules (no data loss on recursion)' do
    modules = CreateTests.send(:get_modules, TestSwagger)
    expect(modules.size).to eq(2)
  end

  it 'accepts a string argument' do
    modules = CreateTests.send(:get_modules, "FlatSwagger")
    expect(modules).to include("FlatSwagger::Products")
  end

  it 'returns unique modules' do
    modules = CreateTests.send(:get_modules, TestSwagger)
    expect(modules).to eq(modules.uniq)
  end
end
