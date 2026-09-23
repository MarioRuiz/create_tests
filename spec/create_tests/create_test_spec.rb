require 'spec_helper'

RSpec.describe CreateTests, '#create_test' do
  before(:all) do
    # Simple constant needed for keyword_required detection: the code checks
    # Object.const_defined?(p[1].to_s.upcase), so we need a constant named
    # e.g., "FORMAT" to match a keyword param named :format
    FORMAT_CONST = "json" unless defined?(FORMAT_CONST)

    module TestApi
      module Products
        def self.list_products(latitude, longitude)
          {
            path: "/v1/products?latitude=#{latitude}&longitude=#{longitude}&",
            method: :get,
            responses: {
              '200': {
                message: "An array of products",
                data: [{ product_id: "string", description: "string" }],
              },
              '401': {
                message: "Unauthorized",
              },
            },
          }
        end

        def self.no_params_endpoint
          {
            path: "/v1/status",
            method: :get,
            responses: {
              '200': { message: "OK" },
            },
          }
        end

        def self.post_with_data
          {
            path: "/v1/products",
            method: :post,
            data: { name: "string", price: 0 },
            data_required: [:name],
            responses: {
              '201': { message: "Created", data: { id: 0, name: "string" } },
              '400': { message: "Bad Request" },
            },
          }
        end

        def self.with_mock_response
          {
            path: "/v1/products",
            method: :get,
            mock_response: {
              code: "200",
              message: "An array of products",
              data: [{ product_id: "string" }],
            },
            responses: {
              '200': { message: "An array of products", data: [{ product_id: "string" }] },
            },
          }
        end

        def self.put_with_data
          {
            path: "/v1/products/1",
            method: :put,
            data: { name: :"5-20:L", price: 0 },
            responses: {
              '200': { message: "Updated", data: { id: 0, name: "string" } },
              '400': { message: "Bad Request" },
            },
          }
        end

        def self.get_with_data
          {
            path: "/v1/search",
            method: :get,
            data: { query: "test" },
            responses: {
              '200': { message: "OK" },
            },
          }
        end

        def self.with_data_pattern
          {
            path: "/v1/products",
            method: :get,
            data_pattern: { product_id: /\d+/ },
            responses: {
              '200': {
                message: "OK",
                data: { product_id: "123" },
              },
            },
          }
        end

        def self.post_with_data_and_pattern
          {
            path: "/v1/products",
            method: :post,
            data: { name: "string", price: 0 },
            data_pattern: { name: :"5-20:L", price: 1..100 },
            responses: {
              '201': { message: "Created", data: { id: 0, name: "string" } },
              '400': { message: "Bad Request" },
            },
          }
        end

        def self.post_with_pattern_only
          {
            path: "/v1/products",
            method: :post,
            data_pattern: { name: :"5-20:L", price: 1..100 },
            responses: {
              '201': { message: "Created" },
              '400': { message: "Bad Request" },
            },
          }
        end

        def self.post_with_data_examples_only
          {
            path: "/v1/upload",
            method: :post,
            data_examples: [{ file: "report.csv", note: "quarterly" }],
            data_required: [:file],
            responses: {
              '201': { message: "Uploaded", data: { id: "string" } },
              '400': { message: "Bad Request" },
            },
          }
        end

        def self.mock_without_data
          {
            path: "/v1/ping",
            method: :get,
            mock_response: {
              code: "200",
              message: "pong",
            },
            responses: {
              '200': { message: "pong" },
            },
          }
        end

        def self.with_4xx_responses(product_id)
          {
            path: "/v1/products/#{product_id}",
            method: :get,
            responses: {
              '200': { message: "OK", data: { id: "string" } },
              '401': { message: "Unauthorized", data: { error: "string" } },
              '404': { message: "Not Found", data: { error: "string" } },
            },
          }
        end

        def self.no_responses
          {
            path: "/v1/health",
            method: :get,
          }
        end

        def self.empty_responses
          {
            path: "/v1/health",
            method: :get,
            responses: {},
          }
        end
      end
    end

    module TestApiHierarchical
      module Volumes
        def self.create_or_update(subscription_id, resource_group_name, account_name, pool_name, volume_name)
          {
            path: "/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.NetApp/netAppAccounts/#{account_name}/capacityPools/#{pool_name}/volumes/#{volume_name}?api-version=2019",
            method: :put,
            data: { location: "eastus" },
            data_required: [:location],
            responses: {
              '201': { message: "Created", data: { id: "string" } },
              '400': { message: "Bad Request" },
            },
          }
        end
      end

      module Snapshots
        def self.delete(subscription_id, resource_group_name, account_name, pool_name, volume_name, snapshot_name)
          {
            path: "/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.NetApp/netAppAccounts/#{account_name}/capacityPools/#{pool_name}/volumes/#{volume_name}/snapshots/#{snapshot_name}?api-version=2019",
            method: :delete,
            responses: { '200': { message: "OK" } },
          }
        end

        def self.get(subscription_id, resource_group_name, account_name, pool_name, volume_name, snapshot_name)
          {
            path: "/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.NetApp/netAppAccounts/#{account_name}/capacityPools/#{pool_name}/volumes/#{volume_name}/snapshots/#{snapshot_name}?api-version=2019",
            method: :get,
            responses: { '200': { message: "OK", data: { name: "string" } } },
          }
        end

        def self.update(subscription_id, resource_group_name, account_name, pool_name, volume_name, snapshot_name)
          {
            path: "/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.NetApp/netAppAccounts/#{account_name}/capacityPools/#{pool_name}/volumes/#{volume_name}/snapshots/#{snapshot_name}?api-version=2019",
            method: :patch,
            data: { location: "eastus" },
            responses: { '200': { message: "OK", data: { name: "string" } } },
          }
        end
      end

      module SimpleOps
        def self.list_operations
          {
            path: "/providers/Microsoft.NetApp/operations?api-version=2019",
            method: :get,
            responses: { '200': { message: "OK" } },
          }
        end
      end
    end

    CreateTests.instance_variable_set(:@logger, Logger.new(nil))
    CreateTests.instance_variable_set(:@params, [])
    CreateTests.instance_variable_set(:@setup_cleanup_resources, [])
  end

  after(:all) do
    Object.send(:remove_const, :TestApi)
    Object.send(:remove_const, :TestApiHierarchical) if defined?(TestApiHierarchical)
  end

  def generate(method_name, test_txt = "", mod_path: "TestApi::Products", **kwargs)
    CreateTests.instance_variable_set(:@params, [])
    CreateTests.instance_variable_set(:@setup_cleanup_resources, [])
    mod = Object.const_get(mod_path)
    CreateTests.send(
      :create_test, mod_path, method_name,
      mod.method(method_name), test_txt, **kwargs
    )
  end

  it 'generates RSpec structure for a new test' do
    _modified, output = generate(:no_params_endpoint)
    expect(output).to include("RSpec.describe Products")
    expect(output).to include("#no_params_endpoint")
    expect(output).to include("require_relative")
    expect(output).to include("NiceHttp.new()")
  end

  it 'generates successful response test' do
    _modified, output = generate(:no_params_endpoint)
    expect(output).to include("has correct structure in successful response")
    expect(output).to include("expect(resp.code).to eq")
  end

  it 'generates authentication test' do
    _modified, output = generate(:no_params_endpoint)
    expect(output).to include("doesn\\'t retrieve data if not authenticated")
    expect(output).to include("http.headers = {}")
    expect(output).to include("be_between('400', '499')")
  end

  it 'generates parameter validation tests for endpoints with required params' do
    _modified, output = generate(:list_products)
    expect(output).to include("returns error if required parameter empty")
  end

  it 'generates data validation tests for endpoints with required data fields' do
    _modified, output = generate(:post_with_data)
    expect(output).to include("returns error if required parameter on data empty")
    expect(output).to include("returns error if required parameter on data missing")
  end

  it 'generates mock response test when mock_response is present' do
    _modified, output = generate(:with_mock_response)
    expect(output).to include("returns expected mock response")
    expect(output).to include("use_mocks = true")
    expect(output).to include("mock_response")
  end

  it 'generates mock response test without data comparison when no data in mock' do
    _modified, output = generate(:mock_without_data)
    expect(output).to include("returns expected mock response")
    expect(output).not_to include("compare_structure(@request[:mock_response][:data]")
  end

  it 'returns modified=true for new tests' do
    modified, _output = generate(:no_params_endpoint)
    expect(modified).to be true
  end

  it 'does not duplicate tests in append mode' do
    _modified, first_output = generate(:no_params_endpoint)
    modified, second_output = generate(:no_params_endpoint, first_output)
    expect(modified).to be false
    expect(second_output.scan("has correct structure in successful response").size).to eq(1)
  end

  it 'uses custom settings_relative_path when provided' do
    CreateTests.instance_variable_set(:@params, [])
    mod = TestApi::Products
    _modified, output = CreateTests.send(
      :create_test, "TestApi::Products", :no_params_endpoint,
      mod.method(:no_params_endpoint), "",
      settings_relative_path: '../../config/general'
    )
    expect(output).to include("require_relative '../../config/general'")
  end

  it 'populates @params with required parameters' do
    generate(:list_products)
    params = CreateTests.instance_variable_get(:@params)
    expect(params).to include("@latitude")
    expect(params).to include("@longitude")
  end

  it 'uses validate_response with diff for structure comparison when response has data' do
    _modified, output = generate(:list_products)
    expect(output).to include("NiceHttp.validate_response")
    expect(output).to include("include_diff: true")
    expect(output).to include("Structure mismatch")
  end

  it 'uses validate_response for data_pattern endpoints too' do
    _modified, output = generate(:with_data_pattern)
    expect(output).to include("NiceHttp.validate_response")
    expect(output).to include("include_diff: true")
  end

  it 'handles endpoint with no responses key' do
    _modified, output = generate(:no_responses)
    expect(output).to include("RSpec.describe")
    expect(output).not_to include("has correct structure in successful response")
  end

  it 'handles endpoint with empty responses hash' do
    _modified, output = generate(:empty_responses)
    expect(output).to include("RSpec.describe")
    expect(output).not_to include("has correct structure in successful response")
  end

  it 'includes 4xx response checks in auth test when 4xx responses exist' do
    _modified, output = generate(:with_4xx_responses)
    expect(output).to include("doesn\\'t retrieve data if not authenticated")
    expect(output).to include("compare_structure(@request.responses[resp.code.to_sym].data")
  end

  it 'includes 4xx message checks in param empty test' do
    _modified, output = generate(:with_4xx_responses)
    expect(output).to include("returns error if required parameter empty")
    expect(output).to include("resp.message")
  end

  it 'generates fuzz test with generate_n for POST endpoints with data' do
    _modified, output = generate(:post_with_data)
    expect(output).to include("handles multiple valid data variations")
    expect(output).to include("generate_n(5, :correct)")
    expect(output).to include("be_between(200, 299)")
  end

  it 'generates fuzz test with generate_n for PUT endpoints with data' do
    _modified, output = generate(:put_with_data)
    expect(output).to include("handles multiple valid data variations")
    expect(output).to include("generate_n(5, :correct)")
  end

  it 'does not generate fuzz test for GET endpoints' do
    _modified, output = generate(:get_with_data)
    expect(output).not_to include("handles multiple valid data variations")
  end

  it 'generates change_one_by_one test for endpoints with data' do
    _modified, output = generate(:post_with_data)
    expect(output).to include("returns error when individual data fields are invalid")
    expect(output).to include("change_one_by_one")
    expect(output).to include("errors: :min_length")
  end

  it 'generates change_one_by_one test for GET endpoints with data too' do
    _modified, output = generate(:get_with_data)
    expect(output).to include("returns error when individual data fields are invalid")
    expect(output).to include("change_one_by_one")
  end

  it 'does not generate fuzz or change_one_by_one for endpoints without data' do
    _modified, output = generate(:no_params_endpoint)
    expect(output).not_to include("handles multiple valid data variations")
    expect(output).not_to include("returns error when individual data fields are invalid")
  end

  it 'prefers data_pattern over type-hint data for generate_n and change_one_by_one' do
    _modified, output = generate(:post_with_data_and_pattern)
    expect(output).to include("@request[:data_pattern].generate_n(5, :correct)")
    expect(output).to include("NiceHash.change_one_by_one([@request[:data_pattern], :correct]")
    expect(output).to include("request[:data] = generated_data")
    expect(output).to include("request[:data] = one_wrong")
    expect(output).not_to include("@request[:data].generate_n")
    expect(output).not_to include("change_one_by_one([@request[:data],")
  end

  it 'falls back to :data for generate_n when data_pattern is absent' do
    _modified, output = generate(:post_with_data)
    expect(output).to include("@request[:data].generate_n(5, :correct)")
    expect(output).to include("NiceHash.change_one_by_one([@request[:data], :correct]")
  end

  it 'uses data_pattern alone for generate_n when :data is absent' do
    _modified, output = generate(:post_with_pattern_only)
    expect(output).to include("@request[:data_pattern].generate_n(5, :correct)")
    expect(output).to include("returns error when individual data fields are invalid")
  end

  it 'uses data_examples.first for success and required-data tests when :data is missing' do
    _modified, output = generate(:post_with_data_examples_only)
    expect(output).to include("request = @request.deep_copy")
    expect(output).to include("request[:data] = @request[:data_examples].first")
    expect(output).to include("returns error if required parameter on data empty")
    expect(output).to include("returns error if required parameter on data missing")
    expect(output).to include("request[:data] = request[:data_examples].first")
    expect(output).not_to include("handles multiple valid data variations")
    expect(output).not_to include("returns error when individual data fields are invalid")
  end

  describe 'append mode with existing test content' do
    it 'appends missing tests with timestamp to existing content' do
      partial_output = <<~RUBY
        require_relative '../../settings/general'
        if defined?(Products) and defined?(Products.no_params_endpoint)
          RSpec.describe Products, '#no_params_endpoint' do
          before(:all) do
            @http = NiceHttp.new()
            @request = Products.no_params_endpoint()
          end
          before(:each) do |example|
          end
        it 'has correct structure in successful response' do
                resp = @http.get(@request)
                expect(resp.code).to eq 200
        end
        end
        end
      RUBY

      modified, output = generate(:no_params_endpoint, partial_output)
      expect(modified).to be true
      expect(output).to include("# Appended")
      expect(output).to include("doesn\\'t retrieve data if not authenticated")
    end

    it 'handles existing content with double end (no triple end match)' do
      partial_output = <<~RUBY
        RSpec.describe Products, '#no_params_endpoint' do
        it 'has correct structure in successful response' do
                resp = @http.get(@request)
        end
        end
      RUBY

      modified, output = generate(:no_params_endpoint, partial_output)
      expect(modified).to be true
      expect(output).to include("doesn\\'t retrieve data if not authenticated")
    end

    it 'handles existing content with triple end' do
      partial_output = <<~RUBY
        require_relative '../../settings/general'
        if defined?(Products) and defined?(Products.no_params_endpoint)
          RSpec.describe Products, '#no_params_endpoint' do
        it 'has correct structure in successful response' do
                resp = @http.get(@request)
        end
        end
        end
        end
      RUBY

      modified, output = generate(:no_params_endpoint, partial_output)
      expect(modified).to be true
      expect(output).to include("doesn\\'t retrieve data if not authenticated")
    end
  end

  describe 'keyword required parameters' do
    before(:all) do
      # Define a constant that the keyword detection code will find
      Object.const_set(:REGION, "us-east") unless Object.const_defined?(:REGION)
      Object.const_set(:ID, "item-1") unless Object.const_defined?(:ID)

      module TestApiKw
        module Services
          def self.get_service(region: "default")
            {
              path: "/v1/services?region=#{region}",
              method: :get,
              responses: {
                '200': { message: "OK" },
                '400': { message: "Bad Request" },
              },
            }
          end

          def self.get_item(id: ID)
            {
              path: "/v1/items/#{id}",
              method: :get,
              responses: {
                '200': { message: "OK", data: { id: "string" } },
                '400': { message: "Bad Request" },
              },
            }
          end

          def self.list_optional(offset: "")
            {
              path: "/v1/items?offset=#{offset}",
              method: :get,
              responses: {
                '200': { message: "OK" },
              },
            }
          end

          def self.mixed(name, id: ID)
            {
              path: "/v1/items/#{id}?name=#{name}",
              method: :get,
              responses: {
                '200': { message: "OK" },
                '400': { message: "Bad Request" },
              },
            }
          end

          def self.keyreq_only(token:)
            {
              path: "/v1/secure?token=#{token}",
              method: :get,
              responses: {
                '200': { message: "OK" },
                '400': { message: "Bad Request" },
              },
            }
          end
        end
      end
    end

    after(:all) do
      Object.send(:remove_const, :TestApiKw)
    end

    it 'generates keyword parameter validation test' do
      CreateTests.instance_variable_set(:@params, [])
      CreateTests.instance_variable_set(:@setup_cleanup_resources, [])
      CreateTests.instance_variable_set(:@logger, Logger.new(nil))
      mod = TestApiKw::Services
      _modified, output = CreateTests.send(
        :create_test, "TestApiKw::Services", :get_service,
        mod.method(:get_service), ""
      )
      expect(output).to include("returns error if required parameter empty")
      expect(output).to include(":region")
      expect(output).to include("kw =>")
    end

    it 'creates Helper stub and keyword call for create_constants id: ID' do
      CreateTests.instance_variable_set(:@params, [])
      CreateTests.instance_variable_set(:@setup_cleanup_resources, [])
      CreateTests.instance_variable_set(:@logger, Logger.new(nil))
      mod = TestApiKw::Services
      _modified, output = CreateTests.send(
        :create_test, "TestApiKw::Services", :get_item,
        mod.method(:get_item), ""
      )
      expect(output).to include("@id = Helper.id(@http)")
      expect(output).to include("Services.get_item(id: @id)")
      expect(CreateTests.instance_variable_get(:@params)).to include("@id")
      expect(output).to include("kw =>")
    end

    it 'does not create Helper stub for optional keyword without UPCASE constant' do
      CreateTests.instance_variable_set(:@params, [])
      CreateTests.instance_variable_set(:@setup_cleanup_resources, [])
      CreateTests.instance_variable_set(:@logger, Logger.new(nil))
      mod = TestApiKw::Services
      _modified, output = CreateTests.send(
        :create_test, "TestApiKw::Services", :list_optional,
        mod.method(:list_optional), ""
      )
      expect(output).not_to include("Helper.offset")
      expect(output).not_to include("@offset =")
      expect(CreateTests.instance_variable_get(:@params)).not_to include("@offset")
      expect(output).to include("Services.list_optional()")
    end

    it 'supports mixed positional and keyword params' do
      CreateTests.instance_variable_set(:@params, [])
      CreateTests.instance_variable_set(:@setup_cleanup_resources, [])
      CreateTests.instance_variable_set(:@logger, Logger.new(nil))
      mod = TestApiKw::Services
      _modified, output = CreateTests.send(
        :create_test, "TestApiKw::Services", :mixed,
        mod.method(:mixed), ""
      )
      expect(output).to include("@name = Helper.name(@http)")
      expect(output).to include("@id = Helper.id(@http)")
      expect(output).to include("Services.mixed(@name, id: @id)")
    end

    it 'treats :keyreq as required and fetches request hash without positional nils' do
      CreateTests.instance_variable_set(:@params, [])
      CreateTests.instance_variable_set(:@setup_cleanup_resources, [])
      CreateTests.instance_variable_set(:@logger, Logger.new(nil))
      mod = TestApiKw::Services
      expect {
        _modified, output = CreateTests.send(
          :create_test, "TestApiKw::Services", :keyreq_only,
          mod.method(:keyreq_only), ""
        )
        expect(output).to include("@token = Helper.token(@http)")
        expect(output).to include("Services.keyreq_only(token: @token)")
      }.not_to raise_error
    end
  end

  describe 'only and minitest generation' do
    it 'filters examples by only:' do
      _modified, output = generate(:post_with_data, only: [:success, :mock])
      expect(output).to include("has correct structure in successful response")
      expect(output).not_to include("doesn\\'t retrieve data if not authenticated")
      expect(output).not_to include("handles multiple valid data variations")
      expect(output).not_to include("returns error when individual data fields are invalid")
    end

    it 'raises for unknown only kinds' do
      expect {
        generate(:no_params_endpoint, only: [:nope])
      }.to raise_error(RuntimeError, /Wrong only/)
    end

    it 'generates Minitest classes with assert helpers' do
      _modified, output = generate(:no_params_endpoint, test: :minitest)
      expect(output).to include("require 'minitest/autorun'")
      expect(output).to include("class ProductsNoParamsEndpointTest < Minitest::Test")
      expect(output).to include("def setup")
      expect(output).to include("def teardown")
      expect(output).to include("def test_has_correct_structure_in_successful_response")
      expect(output).to include("assert_equal")
      expect(output).to include("assert_includes")
      expect(output).not_to include("expect(")
      expect(output).not_to include("RSpec.describe")
    end

    it 'does not duplicate minitest methods in append mode' do
      _modified, first = generate(:no_params_endpoint, test: :minitest)
      modified, second = generate(:no_params_endpoint, first, test: :minitest)
      expect(modified).to be false
      expect(second.scan("def test_has_correct_structure_in_successful_response").size).to eq(1)
    end

    it 'maps hierarchical setup expectations for minitest' do
      _modified, output = generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes", test: :minitest)
      expect(output).to include("assert_equal 'Succeeded', Helper.setup_capacity_pools(")
      expect(output).to match(/@volume_name = @volume_name \+ "-createorupda"/)
    end
  end

  describe 'prerequisite setup and cleanup generation' do
    it 'wraps setup call in expect(...state).to eq Succeeded' do
      _modified, output = generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes")
      expect(output).to include("expect(Helper.setup_capacity_pools(")
      expect(output).to include(".state).to eq 'Succeeded'")
    end

    it 'generates single setup call for deepest prerequisite on PUT' do
      _modified, output = generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes")
      expect(output).to include("Helper.setup_capacity_pools")
      expect(output).not_to include("Helper.setup_volumes")
    end

    it 'wraps after(:all) cleanup in DONT_DELETE guard' do
      _modified, output = generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes")
      expect(output).to include("unless defined?(DONT_DELETE) && DONT_DELETE")
      expect(output).to include("Helper.cleanup_capacity_pools")
    end

    it 'does not generate after block when cleanup is false' do
      _modified, output = generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes", cleanup: false)
      expect(output).not_to include("after(")
      expect(output).not_to include("Helper.cleanup_")
      expect(output).to include("Helper.setup_")
    end

    it 'moves after(:all) cleanup into after(:each) when cleanup is :after_each' do
      _modified, output = generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes", cleanup: :after_each)
      expect(output).not_to include("after(:all)")
      expect(output).to include("after(:each)")
      expect(output).to include("Helper.cleanup_capacity_pools")
      expect(output).to include("unless defined?(DONT_DELETE)")
    end

    it 'raises for an unknown cleanup value' do
      expect {
        generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes", cleanup: :bogus)
      }.to raise_error(RuntimeError, /Wrong cleanup/)
    end

    it 'does not generate setup for target resource on PUT (create_or_update)' do
      _modified, output = generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes")
      expect(output).not_to include("Helper.setup_volumes")
    end

    describe 'DELETE endpoints' do
      it 'sets up parents in before(:all) and target in before(:each)' do
        _modified, output = generate(:delete, mod_path: "TestApiHierarchical::Snapshots")
        before_all = output[output.index("before(:all)")..output.index("before(:each)")]
        before_each = output[output.index("before(:each)")..]
        expect(before_all).to include("Helper.setup_volumes")
        expect(before_all).not_to include("Helper.setup_snapshots")
        expect(before_each).to include("Helper.setup_snapshots")
      end

      it 'creates new http connection in before(:each)' do
        _modified, output = generate(:delete, mod_path: "TestApiHierarchical::Snapshots")
        before_each = output[output.index("before(:each)")..]
        expect(before_each).to include("@http = NiceHttp.new()")
      end

      it 'generates after(:each) for target cleanup' do
        _modified, output = generate(:delete, mod_path: "TestApiHierarchical::Snapshots")
        expect(output).to include("after(:each)")
        expect(output).to include("Helper.cleanup_snapshots")
      end

      it 'generates after(:all) with DONT_DELETE guard for parent cleanup' do
        _modified, output = generate(:delete, mod_path: "TestApiHierarchical::Snapshots")
        after_all = output[output.index("after(:all)")..]
        expect(after_all).to include("unless defined?(DONT_DELETE) && DONT_DELETE")
        expect(after_all).to include("Helper.cleanup_volumes")
      end

      it 'moves parent cleanup into after(:each) when cleanup is :after_each' do
        _modified, output = generate(:delete, mod_path: "TestApiHierarchical::Snapshots", cleanup: :after_each)
        expect(output).not_to include("after(:all)")
        expect(output.scan("after(:each)").size).to be >= 2
        expect(output).to include("Helper.cleanup_snapshots")
        expect(output).to include("Helper.cleanup_volumes")
        expect(output).to include("unless defined?(DONT_DELETE)")
      end
    end

    it 'puts GET target cleanup in after(:each) when cleanup is :after_each' do
      _modified, output = generate(:get, mod_path: "TestApiHierarchical::Snapshots", cleanup: :after_each)
      expect(output).not_to include("after(:all)")
      expect(output).to include("after(:each)")
      expect(output).to include("Helper.cleanup_snapshots")
    end

    it 'generates setup for target resource on GET endpoints in before(:all)' do
      _modified, output = generate(:get, mod_path: "TestApiHierarchical::Snapshots")
      expect(output).to include("Helper.setup_snapshots")
    end

    it 'generates setup for target resource on PATCH endpoints in before(:all)' do
      _modified, output = generate(:update, mod_path: "TestApiHierarchical::Snapshots")
      expect(output).to include("Helper.setup_snapshots")
    end

    it 'does not generate setup/cleanup for simple endpoints without hierarchy' do
      _modified, output = generate(:list_operations, mod_path: "TestApiHierarchical::SimpleOps")
      expect(output).not_to include("Helper.setup_")
      expect(output).not_to include("Helper.cleanup_")
      expect(output).not_to include("after(")
    end

    it 'does not generate setup/cleanup for flat path endpoints' do
      _modified, output = generate(:no_params_endpoint)
      expect(output).not_to include("Helper.setup_")
      expect(output).not_to include("after(")
    end

    it 'collects setup_cleanup_resources for helper generation' do
      generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes")
      resources = CreateTests.instance_variable_get(:@setup_cleanup_resources)
      expect(resources).not_to be_empty
      resource_names = resources.map { |r| r[:resource] }
      expect(resource_names).to include("capacity_pools")
      expect(resource_names).to include("net_app_accounts")
    end

    it 'appends per-spec suffix to last param for unique resource names' do
      _modified, output = generate(:delete, mod_path: "TestApiHierarchical::Snapshots")
      expect(output).to match(/@snapshot_name = @snapshot_name \+ "-delete"/)
    end

    it 'derives suffix from method name without underscores, capped at 12' do
      _modified, output = generate(:create_or_update, mod_path: "TestApiHierarchical::Volumes")
      expect(output).to match(/@volume_name = @volume_name \+ "-createorupda"/)
    end
  end
end
