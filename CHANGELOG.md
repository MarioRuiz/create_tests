# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-09-23

### Added
- **data_pattern for variation/invalid-field tests**: When a request hash includes `:data_pattern` (from open_api_import 0.12.2+), `generate_n` and `NiceHash.change_one_by_one` tests use that key instead of type-hint `:data`. Expanded payloads are still assigned to `request[:data]` before the HTTP call. Falls back to `:data` when `:data_pattern` is absent.
- **data_examples as request body**: When `:data` is missing and `:data_examples` is a non-empty array (e.g. form uploads), the successful-response test and required-data empty/missing tests seed `request[:data]` from the first example. Fuzz/invalid-field tests are not invented from plain example literals alone.
- **create_constants keyword Helper stubs**: Required keyword parameters (`id: ID` with an UPCASE constant default, or `:keyreq`) get Helper methods, `@id = Helper.id(@http)` declarations, and keyword calls such as `Items.get_item(id: @id)`. Optional keywords without an UPCASE constant are left alone. Empty-keyword validation (`kw => ''`) is unchanged.

## [1.0.0] - 2026-09-23

### Added
- `CreateTests::VERSION` constant
- `--version` / `-v` CLI flag
- `return_data` option to get generated code as a Hash without writing files
- `--dry_run` / `-d` CLI flag to preview output without writing files
- Configurable `spec_dir` and `settings_dir` output directory parameters
- Mock response test generation for requests that include `mock_response` data (from `open_api_import`)
- **Fuzz test generation**: POST/PUT/PATCH endpoints with `:data` now generate a "handles multiple valid data variations" test using `generate_n(5, :correct)` from nice_hash 1.19
- **Field-by-field validation test**: Endpoints with `:data` now generate a "returns error when individual data fields are invalid" test using `NiceHash.change_one_by_one` for systematic one-field-at-a-time testing
- **Better failure messages**: Successful response structure test now uses `NiceHttp.validate_response` with `include_diff: true` for detailed diff output on mismatch (requires nice_http 1.10+)
- **Prerequisite setup and cleanup**: Automatically infers resource dependency chains from request paths (e.g. Volume requires CapacityPool requires Account) and generates a single `Helper.setup_*` / `Helper.cleanup_*` call in tests. Each setup/cleanup method cascades internally to its parent resources.
- **Helper folder structure**: Setup and cleanup methods are generated in `helper/setup.rb` and `helper/cleanup.rb` with cascading parent calls, keeping the main `helper.rb` clean with only parameter stubs. Setup stubs return `OpenStruct.new(state: "Succeeded")` by default.
- **Setup expectations**: Setup calls are wrapped in `expect(Helper.setup_X(...).state).to eq "Succeeded"` to assert prerequisite creation succeeded.
- **DELETE endpoint pattern**: Target resource is created in `before(:each)` (fresh for each test) and cleaned up in `after(:each)`. Parent resources are set up in `before(:all)` and cleaned up in `after(:all)`.
- **DONT_DELETE guard**: `after(:all)` cleanup is wrapped in `unless defined?(DONT_DELETE) && DONT_DELETE` so users can keep resources for debugging.
- **Per-spec unique suffix**: Each generated test appends a short suffix derived from the method name (e.g., `-del`, `-cre`, `-get`) to the target resource parameter to avoid collisions between spec files.
- `cleanup` parameter: `:after_all` (default), `:after_each`, or `false`. Controls whether and how cleanup hooks are generated.
- `--cleanup_each` and `--no_cleanup` CLI flags
- GitHub Actions CI workflow (`.github/workflows/ci.yml`) testing Ruby 3.0-3.4
- Unit tests for all modules (`get_modules`, `create_test`, `create_helper`, `create_settings`, `from`)
- `CHANGELOG.md`

### Changed
- **BREAKING**: Minimum Ruby version raised from 2.7 to 3.0
- **Dependency**: `nice_hash` constraint updated from `~> 1.18` to `~> 1.19` (leverages `generate_n`, `change_one_by_one`, `diff`, and `:uuid` support)
- Structure comparison in generated tests replaced: `NiceHash.compare_structure` calls replaced with `NiceHttp.validate_response` + diff for clearer assertion messages
- `eval()` calls removed -- replaced with `require`, `Object.const_get`, and `Method#call`
- `rescue Exception` replaced with `rescue StandardError` (no longer swallows Ctrl-C/OOM)
- Shell commands for `rufo` now use `system()` multi-arg form (no shell interpolation)
- `kind_of?` standardized to `is_a?`
- CLI `--append` description corrected (previously duplicated the `--overwrite` description)
- CLI `--overwrite` description typo fixed ("ovewritten" -> "overwritten")
- Gemspec version sourced from `CreateTests::VERSION` constant

### Fixed
- Bug in `get_modules`: sibling modules with nested children were lost during recursion (`modules =` replaced with `modules +=`)
- Typo in generated settings: "Auhentication" corrected to "Authentication"
- Generated settings now require the requests file with a path relative to `settings_dir`
- Relative `require_relative` paths resolve symlinks (e.g. macOS `/tmp` → `/private/tmp`) so generated settings load when `settings_dir` is outside the project tree
- `spec/helper.rb` requires `helper/setup` and `helper/cleanup` only when those files are generated, using a path relative to `spec_dir`
- Setup stubs return `OpenStruct` so generated `expect(...).state` assertions succeed
- Append mode leaves existing `helper/setup.rb` and `helper/cleanup.rb` unchanged
- `cleanup: :after_each` moves `after(:all)` cleanup hooks into `after(:each)`

### Removed
- Travis CI configuration (`.travis.yml`), superseded by GitHub Actions
- Coveralls dependency; SimpleCov remains available for local coverage
