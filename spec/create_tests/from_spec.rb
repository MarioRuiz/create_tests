require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe CreateTests, '.from' do
  let(:requests_file) { File.expand_path("../../example/requests/uber.yaml.rb", __dir__) }

  describe 'parameter validation' do
    it 'raises error for non-existent file' do
      expect { CreateTests.from("/nonexistent/file.rb") }.to raise_error(RuntimeError, /doesn't exist/)
    end

    it 'raises error for invalid type parameter' do
      expect { CreateTests.from(requests_file, type: :invalid) }.to raise_error(RuntimeError, /Wrong type/)
    end

    it 'raises error for invalid test parameter' do
      expect { CreateTests.from(requests_file, test: :invalid) }.to raise_error(RuntimeError, /Wrong test/)
    end

    it 'raises error for invalid mode parameter' do
      expect { CreateTests.from(requests_file, mode: :invalid) }.to raise_error(RuntimeError, /Wrong mode/)
    end

    it 'raises error for invalid cleanup parameter' do
      expect { CreateTests.from(requests_file, cleanup: :nope) }.to raise_error(RuntimeError, /Wrong cleanup/)
    end

    it 'raises error for invalid only parameter' do
      expect { CreateTests.from(requests_file, only: :bogus, return_data: true) }.to raise_error(RuntimeError, /Wrong only/)
    end
  end

  describe 'return_data option' do
    it 'returns a Hash of generated files when return_data is true' do
      result = CreateTests.from(requests_file, return_data: true)
      expect(result).to be_a(Hash)
      expect(result.size).to be > 0
    end

    it 'includes settings file in returned data' do
      result = CreateTests.from(requests_file, return_data: true)
      settings_key = result.keys.find { |k| k.include?("general.rb") }
      expect(settings_key).not_to be_nil
      expect(result[settings_key]).to include("NiceHttp")
    end

    it 'requires the requests file relative to the settings directory' do
      result = CreateTests.from(requests_file, return_data: true)
      settings = result.fetch("./settings/general.rb")
      match = settings.match(/require_relative '([^']+uber\.yaml\.rb)'/)
      expect(match).not_to be_nil
      resolved = File.expand_path(match[1], File.expand_path("./settings"))
      expect(File.expand_path(resolved)).to eq(File.expand_path(requests_file))
    end

    it 'does not require setup or cleanup helpers for flat APIs' do
      result = CreateTests.from(requests_file, return_data: true)
      helper = result.fetch("./spec/helper.rb")
      expect(helper).not_to include("helper/setup")
      expect(helper).not_to include("helper/cleanup")
      expect(result.keys.grep(%r{helper/(setup|cleanup)})).to be_empty
    end

    it 'includes helper file in returned data' do
      result = CreateTests.from(requests_file, return_data: true)
      helper_key = result.keys.find { |k| k.include?("helper.rb") }
      expect(helper_key).not_to be_nil
      expect(result[helper_key]).to include("module Helper")
    end

    it 'includes test files in returned data' do
      result = CreateTests.from(requests_file, return_data: true)
      spec_keys = result.keys.select { |k| k.include?("_spec.rb") }
      expect(spec_keys.size).to be > 0
    end

    it 'does not create files on disk when return_data is true' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          CreateTests.from(requests_file, return_data: true)
          expect(Dir.exist?("./spec")).to be false
          expect(Dir.exist?("./settings")).to be false
        end
      end
    end
  end

  describe 'dry_run option' do
    it 'does not create files on disk when dry_run is true' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          CreateTests.from(requests_file, dry_run: true)
          expect(Dir.exist?("./spec")).to be false
          expect(Dir.exist?("./settings")).to be false
        end
      end
    end
  end

  describe 'configurable directories' do
    it 'uses custom spec_dir and settings_dir in returned data' do
      result = CreateTests.from(requests_file, return_data: true, spec_dir: './test/spec', settings_dir: './test/config')
      settings_key = result.keys.find { |k| k.include?("test/config/general.rb") }
      helper_key = result.keys.find { |k| k.include?("test/spec/helper.rb") }
      expect(settings_key).not_to be_nil
      expect(helper_key).not_to be_nil
    end
  end

  describe 'only option' do
    it 'generates only the selected test kinds' do
      result = CreateTests.from(requests_file, return_data: true, only: [:success, :auth])
      spec = result.values.find { |v| v.include?("RSpec.describe") }
      expect(spec).to include("has correct structure in successful response")
      expect(spec).to include("doesn\\'t retrieve data if not authenticated")
      expect(spec).not_to include("returns error if required parameter empty")
      expect(spec).not_to include("handles multiple valid data variations")
    end

    it 'accepts a comma-separated string for only' do
      result = CreateTests.from(requests_file, return_data: true, only: "success")
      spec = result.values.find { |v| v.include?("RSpec.describe") }
      expect(spec).to include("has correct structure in successful response")
      expect(spec).not_to include("doesn\\'t retrieve data if not authenticated")
    end
  end

  describe 'minitest output' do
    it 'writes *_test.rb under ./test by default' do
      result = CreateTests.from(requests_file, return_data: true, test: :minitest)
      test_keys = result.keys.select { |k| k.include?("_test.rb") }
      expect(test_keys).not_to be_empty
      expect(test_keys.first).to start_with("./test/")
      content = result[test_keys.first]
      expect(content).to include("require 'minitest/autorun'")
      expect(content).to include("Minitest::Test")
      expect(content).to include("def setup")
      expect(content).to include("def teardown")
      expect(content).to include("assert_equal")
      expect(content).not_to include("RSpec.describe")
      expect(content).not_to include("expect(")
    end

    it 'honors an explicit spec_dir with minitest' do
      result = CreateTests.from(requests_file, return_data: true, test: :minitest, spec_dir: './spec')
      test_keys = result.keys.select { |k| k.include?("_test.rb") }
      expect(test_keys.first).to start_with("./spec/")
    end
  end

  describe 'file-writing modes' do
    let(:tmpdir) { Dir.mktmpdir }

    after(:each) do
      FileUtils.remove_entry(tmpdir)
    end

    it 'creates spec and settings directories and writes all files' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        expect(Dir.exist?("./spec")).to be true
        expect(Dir.exist?("./settings")).to be true
        expect(File.exist?("./settings/general.rb")).to be true
        expect(File.exist?("./spec/helper.rb")).to be true
        spec_files = Dir["./spec/**/*_spec.rb"]
        expect(spec_files.size).to be > 0
      end
    end

    it 'writes test files with correct content' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        content = File.read(Dir["./spec/**/*_spec.rb"].first)
        expect(content).to include("RSpec.describe")
      end
    end

    it 'overwrite mode warns about overwriting' do
      Dir.chdir(tmpdir) do
        expect {
          CreateTests.from(requests_file, mode: :overwrite)
        }.to output(/Pay attention/).to_stderr
      end
    end

    it 'overwrite mode overwrites existing files' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        first_content = File.read("./settings/general.rb")
        CreateTests.from(requests_file, mode: :overwrite)
        second_content = File.read("./settings/general.rb")
        expect(second_content).to eq(first_content)
      end
    end

    it 'dont_overwrite mode skips existing test files' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        spec_file = Dir["./spec/**/*_spec.rb"].first
        File.write(spec_file, "# custom content")
        expect {
          CreateTests.from(requests_file, mode: :dont_overwrite)
        }.to output(/already exists/).to_stderr
        expect(File.read(spec_file)).to eq("# custom content")
      end
    end

    it 'dont_overwrite mode skips existing helper file' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        expect {
          CreateTests.from(requests_file, mode: :dont_overwrite)
        }.to output(/helper.*already exists/m).to_stderr
      end
    end

    it 'dont_overwrite mode skips existing settings file' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        expect {
          CreateTests.from(requests_file, mode: :dont_overwrite)
        }.to output(/settings.*already exists/m).to_stderr
      end
    end

    it 'append mode reads existing helper and appends new methods' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        helper_content = File.read("./spec/helper.rb")
        expect(helper_content).to include("module Helper")
        CreateTests.from(requests_file, mode: :append)
        updated_content = File.read("./spec/helper.rb")
        expect(updated_content).to include("module Helper")
      end
    end

    it 'append mode does not duplicate tests in existing spec files' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        spec_file = Dir["./spec/**/*_spec.rb"].first
        first_content = File.read(spec_file)
        CreateTests.from(requests_file, mode: :append)
        second_content = File.read(spec_file)
        expect(second_content.scan("has correct structure in successful response").size).to eq(1)
      end
    end

    it 'creates log file during normal operation' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        log_files = Dir["#{File.dirname(requests_file)}/*_create_tests.log"]
        expect(log_files.size).to be >= 1
      end
    end
  end

  describe 'relative path handling' do
    let(:tmpdir) { Dir.mktmpdir }

    after(:each) do
      FileUtils.remove_entry(tmpdir)
    end

    it 'resolves ./ prefixed paths' do
      Dir.chdir(File.dirname(requests_file)) do
        result = CreateTests.from("./#{File.basename(requests_file)}", return_data: true)
        expect(result).to be_a(Hash)
        expect(result.size).to be > 0
      end
    end
  end

  describe 'error handling for bad request files' do
    it 'raises error when request file cannot be loaded' do
      Dir.mktmpdir do |tmpdir|
        bad_file = File.join(tmpdir, "bad_requests.rb")
        File.write(bad_file, "raise StandardError, 'intentional test error'")
        expect {
          CreateTests.from(bad_file, return_data: true)
        }.to raise_error(RuntimeError, /Error evaluating/)
      end
    end
  end

  describe 'module detection' do
    it 'detects OpenApi module' do
      Dir.mktmpdir do |tmpdir|
        req_file = File.join(tmpdir, "openapi_requests.rb")
        File.write(req_file, <<~RUBY)
          module OpenApi
            module TestService
              module V1
                module Items
                  def self.list_items
                    { path: "/items", method: :get, responses: { '200': { message: "OK" } } }
                  end
                end
              end
            end
          end
        RUBY
        allow(Kernel).to receive(:const_defined?).and_call_original
        allow(Kernel).to receive(:const_defined?).with(:Swagger).and_return(false)
        allow(Kernel).to receive(:const_defined?).with(:OpenApi).and_return(true)
        begin
          result = CreateTests.from(req_file, return_data: true)
          expect(result).to be_a(Hash)
          spec_keys = result.keys.select { |k| k.include?("_spec.rb") }
          expect(spec_keys.size).to be > 0
        ensure
          Object.send(:remove_const, :OpenApi) if Object.const_defined?(:OpenApi)
        end
      end
    end

    it 'detects Requests module' do
      Dir.mktmpdir do |tmpdir|
        req_file = File.join(tmpdir, "requests_mod.rb")
        File.write(req_file, <<~RUBY)
          module Requests
            module Ping
              def self.health
                { path: "/health", method: :get, responses: { '200': { message: "OK" } } }
              end
            end
          end
        RUBY
        allow(Kernel).to receive(:const_defined?).and_call_original
        allow(Kernel).to receive(:const_defined?).with(:Swagger).and_return(false)
        allow(Kernel).to receive(:const_defined?).with(:OpenApi).and_return(false)
        allow(Kernel).to receive(:const_defined?).with(:Requests).and_return(true)
        begin
          result = CreateTests.from(req_file, return_data: true)
          expect(result).to be_a(Hash)
          spec_keys = result.keys.select { |k| k.include?("_spec.rb") }
          expect(spec_keys.size).to be > 0
        ensure
          Object.send(:remove_const, :Requests) if Object.const_defined?(:Requests)
        end
      end
    end

    it 'raises error when no recognized module is defined' do
      Dir.mktmpdir do |tmpdir|
        req_file = File.join(tmpdir, "bad_module.rb")
        File.write(req_file, <<~RUBY)
          module UnrecognizedModule
            module Stuff
              def self.do_thing
                { path: "/thing", method: :get }
              end
            end
          end
        RUBY
        allow(Kernel).to receive(:const_defined?).and_call_original
        allow(Kernel).to receive(:const_defined?).with(:Swagger).and_return(false)
        allow(Kernel).to receive(:const_defined?).with(:OpenApi).and_return(false)
        allow(Kernel).to receive(:const_defined?).with(:Requests).and_return(false)
        begin
          expect {
            CreateTests.from(req_file, return_data: true)
          }.to raise_error(RuntimeError, /need to be inside a module named Swagger/)
        ensure
          Object.send(:remove_const, :UnrecognizedModule) if Object.const_defined?(:UnrecognizedModule)
        end
      end
    end
  end

  describe 'resource chain helper files' do
    let(:chain_source) do
      <<~RUBY
        module OpenApi
          module Volumes
            def self.create_or_update(subscription_id, account_name, volume_name)
              {
                path: "/subscriptions/{subscription_id}/accounts/{account_name}/volumes/{volume_name}",
                method: :put,
                responses: { '200': { message: "OK" } },
              }
            end
          end
        end
      RUBY
    end

    def with_chain_api(dir)
      req_file = File.join(dir, "chain_requests.rb")
      File.write(req_file, chain_source)
      allow(Kernel).to receive(:const_defined?).and_call_original
      allow(Kernel).to receive(:const_defined?).with(:Swagger).and_return(false)
      allow(Kernel).to receive(:const_defined?).with(:OpenApi).and_return(true)
      yield req_file
    ensure
      Object.send(:remove_const, :OpenApi) if Object.const_defined?(:OpenApi)
    end

    it 'requires setup and cleanup using a path relative to spec_dir' do
      Dir.mktmpdir do |tmpdir|
        with_chain_api(tmpdir) do |req_file|
          result = CreateTests.from(req_file, return_data: true, spec_dir: "./test/spec")
          helper = result.fetch("./test/spec/helper.rb")
          expect(helper).to include("require_relative '../../helper/setup'")
          expect(helper).to include("require_relative '../../helper/cleanup'")
          expect(result.fetch("./helper/setup.rb")).to include("OpenStruct.new(state: 'Succeeded')")
        end
      end
    end

    it 'appends only missing setup/cleanup methods in append mode' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          with_chain_api(tmpdir) do |req_file|
            CreateTests.from(req_file, mode: :overwrite)
            custom_setup = <<~RUBY
              require 'ostruct'
              module Helper
              def self.setup_accounts(http, subscription_id, account_name)
                # custom body kept
                OpenStruct.new(state: 'Succeeded')
              end
              end
            RUBY
            File.write("./helper/setup.rb", custom_setup)
            CreateTests.from(req_file, mode: :append)
            setup = File.read("./helper/setup.rb")
            expect(setup).to include("# custom body kept")
            expect(setup).to include("def self.setup_accounts(")
            expect(setup).to include("def self.setup_volumes(")
          end
        end
      end
    end

    it 'does not rewrite setup/cleanup when every method already exists' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          with_chain_api(tmpdir) do |req_file|
            CreateTests.from(req_file, mode: :overwrite)
            original_setup = File.read("./helper/setup.rb")
            FileUtils.touch("./helper/setup.rb", mtime: Time.now - 60)
            mtime_before = File.mtime("./helper/setup.rb")
            CreateTests.from(req_file, mode: :append)
            expect(File.read("./helper/setup.rb")).to eq(original_setup)
            expect(File.mtime("./helper/setup.rb")).to eq(mtime_before)
          end
        end
      end
    end

    it 'leaves existing setup and cleanup files untouched in dont_overwrite mode' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          with_chain_api(tmpdir) do |req_file|
            CreateTests.from(req_file, mode: :overwrite)
            File.write("./helper/setup.rb", "# user setup")
            File.write("./helper/cleanup.rb", "# user cleanup")
            CreateTests.from(req_file, mode: :dont_overwrite)
            expect(File.read("./helper/setup.rb")).to eq("# user setup")
            expect(File.read("./helper/cleanup.rb")).to eq("# user cleanup")
          end
        end
      end
    end

    it 'replaces setup and cleanup files in overwrite mode' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          with_chain_api(tmpdir) do |req_file|
            CreateTests.from(req_file, mode: :overwrite)
            File.write("./helper/setup.rb", "# user setup")
            CreateTests.from(req_file, mode: :overwrite)
            expect(File.read("./helper/setup.rb")).to match(/OpenStruct\.new\(state: ['"]Succeeded['"]\)/)
          end
        end
      end
    end
  end

  describe 'append mode updating existing tests' do
    let(:tmpdir) { Dir.mktmpdir }

    after(:each) do
      FileUtils.remove_entry(tmpdir)
    end

    it 'reports test updated when appending new tests to existing file' do
      Dir.chdir(tmpdir) do
        CreateTests.from(requests_file, mode: :overwrite)
        spec_file = Dir["./spec/**/*_spec.rb"].first
        content = File.read(spec_file)
        stripped = content.gsub(/it 'doesn.*?end\n/m, '')
        File.write(spec_file, stripped)
        expect {
          CreateTests.from(requests_file, mode: :append)
        }.to output(/Test updated/).to_stdout
      end
    end
  end
end
