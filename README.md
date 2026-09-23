# CreateTests

[![Gem Version](https://badge.fury.io/rb/create_tests.svg)](https://rubygems.org/gems/create_tests)
[![CI](https://github.com/MarioRuiz/create_tests/actions/workflows/ci.yml/badge.svg)](https://github.com/MarioRuiz/create_tests/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/MarioRuiz/create_tests/master/.github/badges/coverage.json)](https://github.com/MarioRuiz/create_tests/actions/workflows/ci.yml)
![Gem](https://img.shields.io/gem/dt/create_tests)
![GitHub commit activity](https://img.shields.io/github/commit-activity/y/MarioRuiz/create_tests)
![GitHub last commit](https://img.shields.io/github/last-commit/MarioRuiz/create_tests)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/MarioRuiz/create_tests)

Create RSpec tests automatically from Request Hash files. Perfect to be used with the result from importing a Swagger / OpenAPI file using the [open_api_import](https://github.com/MarioRuiz/open_api_import) gem.

We strongly recommend using [nice_http](https://github.com/MarioRuiz/nice_http) for your tests together with [nice_hash](https://github.com/MarioRuiz/nice_hash) and [string_pattern](https://github.com/MarioRuiz/string_pattern).

More info about Request Hashes: https://github.com/MarioRuiz/Request-Hash

## Installation

Install it yourself as:

    $ gem install create_tests

**Requirements:** Ruby >= 3.0

The gem uses [rufo](https://github.com/ruby-formatter/rufo) to format generated files. In case you experience any trouble with it, visit: https://github.com/ruby-formatter/rufo

## Usage

After installation you can run using the command line executable or from Ruby code.

The execution will create:
- A `spec/` folder with one RSpec test file per API endpoint
- A `spec/helper.rb` with stub methods for required parameters
- A `settings/general.rb` with NiceHttp configuration boilerplate

### Command line

```
Usage: create_tests [requests_file] [options]

    -n, --dont_overwrite    In case the test file exists it won't change anything
    -w, --overwrite         In case the test file exists it will be overwritten
    -a, --append            Only missing tests will be appended (default)
    -d, --dry_run           Preview which files would be created or modified
        --cleanup_each      Generate cleanup in after(:each) instead of after(:all)
        --no_cleanup        Do not generate setup/cleanup hooks
    -v, --version           Show version
```

Example:

```bash
create_tests ./requests/uber.yaml.rb
```

Dry run (preview without writing files):

```bash
create_tests ./requests/uber.yaml.rb --dry_run
```

### Ruby API

```ruby
require 'create_tests'

CreateTests.from "./requests/uber.yaml.rb"
```

## Generated tests

For each API endpoint, `create_tests` generates up to 7 test types:

1. **"has correct structure in successful response"** -- Calls the endpoint and validates the response structure using `NiceHttp.validate_response` with diff details on failure.

2. **"doesn't retrieve data if not authenticated"** -- Calls with empty headers and asserts a 4xx response.

3. **"returns error if required parameter empty"** -- For each required parameter, sends an empty string and expects a 4xx response.

4. **"returns expected mock response"** -- For endpoints with `mock_response` data (from `open_api_import`), validates the mock response matches the expected code, message, and structure.

5. **"handles multiple valid data variations"** -- For POST/PUT/PATCH endpoints with a payload source, uses `generate_n(5, :correct)` from nice_hash to test 5 different valid payload variations. Prefers `:data_pattern` when present (real string_pattern / enum / range values from open_api_import); otherwise uses `:data`. Generated values are assigned to `request[:data]` before the call.

6. **"returns error when individual data fields are invalid"** -- Uses `NiceHash.change_one_by_one` on `:data_pattern` (preferred) or `:data` to systematically test each field being wrong one at a time, asserting the server rejects each one.

7. **"returns error if required parameter on data empty/missing"** -- For endpoints with `data_required`, tests both empty and missing values for each required data field. When `:data` is absent but `:data_examples` is present (common for form uploads), the first example is used as the body for success and required-data tests.

Required keyword parameters from open_api_import `create_constants: true` (e.g. `def self.get_item(id: ID)`) get Helper stubs and are called as keywords (`id: @id`), same as positional required args.

## Parameters

### mode

Accepts three options: `:overwrite`, `:dont_overwrite` and `:append`. Default: `:append`.

- **append**: If the test file already exists, only missing tests will be added. Existing content is preserved, including `helper/setup.rb` and `helper/cleanup.rb`. If the file doesn't exist, it will be created with all tests.

- **dont_overwrite**: If the test file exists, no changes will be made. If it doesn't exist, it will be created.

- **overwrite**: The test file will be recreated from scratch. All previous content will be deleted.

```ruby
CreateTests.from "./requests/uber.yaml.rb", mode: :overwrite
```

### dry_run

Preview which files would be created or modified without writing anything to disk.

```ruby
CreateTests.from "./requests/uber.yaml.rb", dry_run: true
```

### return_data

Return the generated code as a Hash (`{ filepath => content }`) without writing files. Useful for programmatic use.

```ruby
result = CreateTests.from "./requests/uber.yaml.rb", return_data: true
result.each { |path, content| puts "#{path}: #{content.length} bytes" }
```

### spec_dir / settings_dir

Custom output directories (default: `./spec` and `./settings`).

```ruby
CreateTests.from "./requests/uber.yaml.rb", spec_dir: "./test/spec", settings_dir: "./test/config"
```

### cleanup

Controls whether and how prerequisite setup/cleanup hooks are generated. Default: `:after_all`.

When API endpoints have hierarchical paths (e.g. `/accounts/{account}/pools/{pool}/volumes/{volume}`), `create_tests` infers the dependency chain and generates production-ready test scaffolding with setup expectations, unique naming, and conditional cleanup.

```ruby
CreateTests.from "./requests/netapp.json.rb"                        # cleanup in after(:all) (default)
CreateTests.from "./requests/netapp.json.rb", cleanup: :after_each  # move after(:all) cleanup into after(:each)
CreateTests.from "./requests/netapp.json.rb", cleanup: false        # no cleanup generation
```

**For PUT/POST (create) endpoints** -- parents are set up, test creates the target:

```ruby
before(:all) do
  @http = NiceHttp.new()
  @volume_name = @volume_name + "-cre"
  expect(Helper.setup_capacity_pools(@http, ...).state).to eq "Succeeded"
  @request = Volumes.create_or_update(...)
end
after(:all) do
  unless defined?(DONT_DELETE) && DONT_DELETE
    Helper.cleanup_capacity_pools(@http, ...)
  end
end
```

**For DELETE endpoints** -- target is recreated before each test (since each test deletes it):

```ruby
before(:all) do
  @snapshot_name = @snapshot_name + "-del"
  expect(Helper.setup_volumes(@http, ...).state).to eq "Succeeded"
  @request = Snapshots.delete(...)
end
before(:each) do |example|
  @http = NiceHttp.new()
  expect(Helper.setup_snapshots(@http, ...).state).to eq "Succeeded"
end
after(:each) do
  Helper.cleanup_snapshots(@http, ...)
end
after(:all) do
  unless defined?(DONT_DELETE) && DONT_DELETE
    Helper.cleanup_volumes(@http, ...)
  end
end
```

**For GET/PATCH endpoints** -- target is set up once in `before(:all)`.

Each setup method cascades to create its parents first (in `helper/setup.rb`):

```ruby
def self.setup_snapshots(http, ...)
  setup_capacity_pools(http, ...)
  # TODO: Create the snapshots resource
  OpenStruct.new(state: "Succeeded")
end
```

Cleanup cascades in reverse (in `helper/cleanup.rb`):

```ruby
def self.cleanup_snapshots(http, ...)
  # TODO: Delete the snapshots resource
  cleanup_capacity_pools(http, ...)
end
```

Set `DONT_DELETE=true` in your environment to keep resources for debugging.

## Example

Creating tests for the Uber API using a Swagger / OpenAPI file:

1. Create a project folder:

```bash
mkdir create_tests_example && cd create_tests_example
```

2. Copy the Swagger file into a `requests` folder (see `./example/requests/uber.yaml` in this repo).

3. Convert the Swagger file into Request Hashes using [open_api_import](https://github.com/MarioRuiz/open_api_import):

```bash
open_api_import ./requests/uber.yaml -fT
```

Output:

```
** Generated files that contain the code of the requests after importing the Swagger file: 
  - requests/uber.yaml_Products.rb
  - requests/uber.yaml_Estimates.rb
  - requests/uber.yaml_User.rb
** File that contains all the requires for all Request files: 
   - requests/uber.yaml.rb 
```

4. Generate the tests:

```bash
create_tests ./requests/uber.yaml.rb
```

Output:

```
- Logs: ./requests/uber.yaml.rb_create_tests.log
- Settings: ./settings/general.rb
- Test created: ./spec/User/profile_user_spec.rb
- Test created: ./spec/User/activity_user_spec.rb
- Test created: ./spec/Products/list_products_spec.rb
- Test created: ./spec/Estimates/price_estimates_spec.rb
- Test created: ./spec/Estimates/time_estimates_spec.rb
- Helper: ./spec/helper.rb
```

5. Review `settings/general.rb` to configure your host and authentication, fill in the Helper methods in `spec/helper.rb`, then run:

```bash
rspec spec/ --format documentation
```

See the full example: https://github.com/MarioRuiz/create_tests/tree/master/example

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MarioRuiz/create_tests.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
