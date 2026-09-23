
class CreateTests

  ##############################################################################
  # Generate tests from a file that contains Request Hashes.
  # More info about Request Hashes: https://github.com/MarioRuiz/Request-Hash
  # @param requests_file [String]. Path and file name. Could be absolute or relative to project root folder.
  # @param type [Symbol]. (default :request_hash). The kind of content that requests_file contains.
  # @param test [Symbol]. (default :rspec). What kind of tests we want to create (:rspec or :minitest).
  # @param mode [Symbol]. (default :append). :overwrite, :append, :dont_overwrite. How we want to create the tests.
  #   :overwrite, it will overwrite the test, settings, helper... files in case they exist so you will loose your original source code.
  #   :dont_overwrite, it will create only the files that don't exist previously
  #   :append, it will append or create the tests or helpers that corrently don't exist on every file, but it won't modify any other code.
  # @param dry_run [Boolean]. (default false). Preview which files would be created or modified without writing anything.
  # @param return_data [Boolean]. (default false). Return a Hash with generated file paths as keys and content as values, without writing files.
  # @param spec_dir [String]. (default './spec' for RSpec, './test' for Minitest). Output directory for generated test files.
  # @param settings_dir [String]. (default './settings'). Output directory for generated settings files.
  # @param cleanup [Symbol, false]. (default :after_all). :after_all, :after_each, or false. Controls cleanup hook generation.
  # @param only [Array, Symbol, String, nil]. (default nil = all). Limit which example kinds are generated.
  ##############################################################################
  def self.from(requests_file, type: :request_hash, test: :rspec, mode: :append, dry_run: false, return_data: false, spec_dir: nil, settings_dir: './settings', cleanup: :after_all, only: nil)
    no_write = dry_run || return_data
    @generated_data = {} if return_data

    begin
      f = File.new("#{requests_file}_create_tests.log", "w") unless no_write
      f.sync = true if f
      @logger = Logger.new(f)
      puts "- Logs: #{requests_file}_create_tests.log" unless no_write
    rescue StandardError => e
      warn "** Not possible to create the Logger file"
      warn e
      @logger = Logger.new nil
    end
    @logger.info "requests_file: #{requests_file}, type: #{type}, test: #{test}, mode: #{mode}"

    requests_file = if requests_file["./"].nil?
                      requests_file
                    else
                      Dir.pwd.to_s + "/" + requests_file.gsub("./", "")
                    end
    unless File.exist?(requests_file)
      message = "** The file #{requests_file} doesn't exist"
      @logger.fatal message
      raise message
    end

    unless [:request_hash].include?(type)
      message = "** Wrong type parameter: #{type}"
      @logger.fatal message
      raise message
    end

    unless [:rspec, :minitest].include?(test)
      message = "** Wrong test parameter: #{test}"
      @logger.fatal message
      raise message
    end

    # Default output dir depends on framework; an explicit spec_dir is always honored.
    if spec_dir.nil?
      spec_dir = test == :minitest ? './test' : './spec'
    end

    unless [:overwrite, :dont_overwrite, :append].include?(mode)
      message = "** Wrong mode parameter: #{mode}"
      @logger.fatal message
      raise message
    end

    unless cleanup == false || [:after_all, :after_each].include?(cleanup)
      message = "** Wrong cleanup parameter: #{cleanup}"
      @logger.fatal message
      raise message
    end

    # Validate only early so bad values fail before generation.
    normalize_only(only)

    if mode == :overwrite
      message = "** Pay attention, if any of the files exist, will be overwritten"
      @logger.warn message
      warn message
    elsif mode == :append
      existing_tests = Dir["#{spec_dir}/*/**_spec.rb"] + Dir["#{spec_dir}/*/**_test.rb"]
      if existing_tests.size > 0
        message = "** Pay attention, if any of the test files exist or the help file exist only will be added the tests, methods that are missing."
        @logger.warn message
        warn message
      end
    end

    @params = Array.new
    @setup_cleanup_resources = Array.new

    require 'pathname'
    # Resolve symlinks (e.g. macOS /tmp -> /private/tmp) so require_relative
    # paths stay valid when settings/spec dirs live outside the project tree.
    resolved_settings_dir = resolve_pathname(settings_dir)
    resolved_spec_dir = resolve_pathname(spec_dir)
    settings_path = resolved_settings_dir.join('general')
    helper_path = resolved_spec_dir.join('helper.rb')
    settings_from_helper = settings_path.relative_path_from(resolved_spec_dir).to_s
    helper_from_settings = helper_path.relative_path_from(resolved_settings_dir).to_s
    requests_from_settings = resolve_pathname(requests_file).relative_path_from(resolved_settings_dir).to_s

    Dir.mkdir spec_dir unless no_write or Dir.exist?(spec_dir)

    add_settings = true
    settings_file = "#{settings_dir}/general.rb"
    helper_file = "#{spec_dir}/helper.rb"
    Dir.mkdir settings_dir unless no_write or Dir.exist?(settings_dir)
    if File.exist?(settings_file) and mode!=:overwrite
      message = "** The file #{settings_file} already exists so no content will be added to it.\n"
      message += "   Remove the settings file to be able to be generated by create_tests or set mode: :overwrite"
      @logger.warn message
      warn message
      add_settings = false
    end
    add_helper = true
    helper_txt = ""
    if File.exist?(helper_file)
      if mode == :dont_overwrite
        message = "** The file #{helper_file} already exists so no content will be added to it.\n"
        message += "   Remove the helper file to be able to be generated by create_tests or set mode: :overwrite or :append"
        @logger.warn message
        warn message
        add_helper = false
      elsif mode == :append
        helper_txt = File.read(helper_file)
      end
    end

    begin
      require requests_file
    rescue StandardError => stack
      message = "\n\n** Error evaluating the ruby file containing the requests: \n" + stack.to_s
      @logger.fatal message
      raise message
    end

    if Kernel.const_defined?(:Swagger)
      first_module = Swagger
    elsif Kernel.const_defined?(:OpenApi)
      first_module = OpenApi
    elsif Kernel.const_defined?(:Requests)
      first_module = Requests
    else
      message = "** The requests need to be inside a module named Swagger, OpenApi or Requests. For example:\n"
      message += "   module Swagger\n  module UberApi\n    module Products\n      def self.list_products\n"
      @logger.fatal message
      raise message
    end

    modules = get_modules(first_module)
    modules.uniq!

    if add_settings
      mods_to_include = []
      modules.each do |m|
        mods_to_include << m.scan(/^(.+)::/).join
      end
      mods_to_include.uniq!
      settings_content = create_settings(requests_from_settings, mods_to_include, helper_relative_path: helper_from_settings)
      if no_write
        @generated_data[settings_file] = settings_content if return_data
        puts "- Settings (dry run): #{settings_file}" if dry_run
      else
        File.open(settings_file, "w") { |file| file.write(settings_content) }
        system("rufo", settings_file, out: File::NULL, err: File::NULL)
      end
      message = "- Settings: #{settings_file}"
      @logger.info message
      puts message unless no_write
    end

    test_suffix = test == :minitest ? "_test.rb" : "_spec.rb"

    modules.each do |mod_txt|
      mod_name = mod_txt.scan(/::(\w+)$/).join
      folder = "#{spec_dir}/#{mod_name}"
      unless no_write or Dir.exist?(folder)
        Dir.mkdir folder
        @logger.info "Created folder: #{folder}"
      end
      mod_obj = Object.const_get(mod_txt)
      mod_methods_txt = mod_obj.methods(false)
      mod_methods_txt.each do |method_txt|
        test_file = "#{folder}/#{method_txt}#{test_suffix}"
        if File.exist?(test_file) and mode==:dont_overwrite
          message = "** The file #{test_file} already exists so no content will be added to it.\n"
          message += "   Remove the test file to be able to be generated by create_tests or set mode: :overwrite, or mode: :append"
          @logger.warn message
          warn message
        else
          if File.exist?(test_file) and mode == :append
            test_txt = File.read(test_file)
          else
            test_txt = ''
          end
          settings_from_test = settings_path.relative_path_from(resolve_pathname(folder)).to_s
          modified, txt = create_test(mod_txt, method_txt, mod_obj.method(method_txt), test_txt, settings_relative_path: settings_from_test, cleanup: cleanup, test: test, only: only)
          if no_write
            @generated_data[test_file] = txt if return_data
          else
            File.open(test_file, "w") { |file| file.write(txt) }
            system("rufo", test_file, out: File::NULL, err: File::NULL)
          end
          if test_txt == ""
            message = "- Test #{no_write ? 'would be created' : 'created'}: #{test_file}"
          elsif modified
            message = "- Test #{no_write ? 'would be updated' : 'updated'}: #{test_file}"
          else
            message = "- Test without changes: #{test_file}"
          end
          @logger.info message
          unless message.include?("without changes")
            puts message
          end
        end
      end
    end

    if add_helper
      @params.uniq!
      helper_dir = "./helper"
      chain_requires = []
      if @setup_cleanup_resources.size > 0
        spec_pathname = Pathname.new(spec_dir)
        chain_requires = [
          Pathname.new("#{helper_dir}/setup").relative_path_from(spec_pathname).to_s,
          Pathname.new("#{helper_dir}/cleanup").relative_path_from(spec_pathname).to_s,
        ]
      end
      helper_content = create_helper(@params, helper_txt, settings_relative_path: settings_from_helper, chain_requires: chain_requires)
      if no_write
        @generated_data[helper_file] = helper_content if return_data
        puts "- Helper (dry run): #{helper_file}" if dry_run
      else
        File.open(helper_file, "w") { |file| file.write(helper_content) }
        system("rufo", helper_file, out: File::NULL, err: File::NULL)
        message = "- Helper: #{helper_file}"
        @logger.info message
        puts message
      end

      if @setup_cleanup_resources.size > 0
        write_chain_file = lambda do |path, content, label|
          if File.exist?(path) && mode == :dont_overwrite
            message = "** The file #{path} already exists so it will be left unchanged.\n"
            message += "   Remove the file to regenerate it or set mode: :overwrite or :append"
            @logger.warn message
            warn message
            return
          end

          if File.exist?(path) && mode == :append
            existing = File.read(path)
            merged, changed = append_missing_chain_methods(existing, content)
            unless changed
              message = "- #{label} without changes: #{path}"
              @logger.info message
              return
            end
            content = merged
            if no_write
              @generated_data[path] = content if return_data
              puts "- #{label} (dry run): #{path}" if dry_run
            else
              File.open(path, "w") { |file| file.write(content) }
              system("rufo", path, out: File::NULL, err: File::NULL)
              message = "- #{label} updated: #{path}"
              @logger.info message
              puts message
            end
            return
          end

          if no_write
            @generated_data[path] = content if return_data
            puts "- #{label} (dry run): #{path}" if dry_run
          else
            Dir.mkdir helper_dir unless Dir.exist?(helper_dir)
            File.open(path, "w") { |file| file.write(content) }
            system("rufo", path, out: File::NULL, err: File::NULL)
            message = "- #{label}: #{path}"
            @logger.info message
            puts message
          end
        end

        write_chain_file.call("#{helper_dir}/setup.rb", create_setup_file(@setup_cleanup_resources), "Helper setup")
        write_chain_file.call("#{helper_dir}/cleanup.rb", create_cleanup_file(@setup_cleanup_resources), "Helper cleanup")
      end
    end

    return @generated_data if return_data
  end

  # Expand path and resolve symlinks for existing ancestors so relative
  # require paths stay valid across mounts like macOS /tmp -> /private/tmp.
  def self.resolve_pathname(path)
    pn = Pathname.new(File.expand_path(path.to_s))
    return pn.realpath if pn.exist?

    missing = []
    current = pn
    until current.exist? || current.root?
      missing.unshift(current.basename)
      current = current.dirname
    end
    resolved = current.exist? ? current.realpath : current
    missing.each { |part| resolved += part }
    resolved
  end
  private_class_method :resolve_pathname
end
