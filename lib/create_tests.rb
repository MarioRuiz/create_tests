
require "logger"

##############################################################################
#
##############################################################################
class CreateTests

  ##############################################################################
  # Generate tests from a file that contains Request Hashes.
  # More info about Request Hashes: https://github.com/MarioRuiz/Request-Hash
  # @param requests_file [String]. Path and file name. Could be absolute or relative to project root folder.
  # @param type [Symbol]. (default :request_hash). The kind of content that requests_file contains.
  # @param test [Symbol]. (default :rspec). What kind of tests we want to create
  # @param mode [Symbol]. (default :append). :overwrite, :append, :dont_overwrite. How we want to create the tests.
  #   :overwrite, it will overwrite the test, settings, helper... files in case they exist so you will loose your original source code.
  #   :dont_overwrite, it will create only the files that don't exist previously
  #   :append, it will append or create the tests or helpers that corrently don't exist on every file, but it won't modify any other code.
  ##############################################################################
  def self.from(requests_file, type: :request_hash, test: :rspec, mode: :append)
    begin
      f = File.new("#{requests_file}_create_tests.log", "w")
      f.sync = true
      @logger = Logger.new f
      puts "- Logs: #{requests_file}_create_tests.log"
    rescue StandardError => e
      warn "** Not possible to create the Logger file"
      warn e
      @logger = Logger.new nil
    end
    @logger.info "requests_file: #{requests_file}, type: #{type}, test: #{test}, mode: #{mode}"
    requests_file_orig = requests_file

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

    unless [:rspec].include?(test)
      message = "** Wrong test parameter: #{test}"
      @logger.fatal message
      raise message
    end

    unless [:overwrite, :dont_overwrite, :append].include?(mode)
      message = "** Wrong mode parameter: #{mode}"
      @logger.fatal message
      raise message
    end

    if mode == :overwrite
      message = "** Pay attention, if any of the files exist, will be overwritten"
      @logger.warn message
      warn message
    elsif mode == :append
      message = "** Pay attention, if any of the test files exist or the help file exist only will be added the tests, methods that are missing."
      @logger.warn message
      warn message
    end

    @params = Array.new

    Dir.mkdir "./spec" unless test != :rspec or Dir.exist?("./spec")

    add_settings = true
    settings_file = "./settings/general.rb"
    helper_file = './spec/helper.rb'
    Dir.mkdir "./settings" unless Dir.exist?("./settings")
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
      eval("require '#{requests_file}'")
    rescue Exception => stack
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
      File.open(settings_file, "w") { |file| file.write(create_settings(requests_file_orig, mods_to_include)) }
      message = "- Settings: #{settings_file}"
      @logger.info message
      puts message
      `rufo #{settings_file}`
    end

    modules.each do |mod_txt|
      mod_name = mod_txt.scan(/::(\w+)$/).join
      folder = "./spec/#{mod_name}"
      unless Dir.exist?(folder)
        Dir.mkdir folder
        @logger.info "Created folder: #{folder}"
      end
      mod_obj = eval("#{mod_txt}")
      mod_methods_txt = eval ("#{mod_txt}.methods(false)")
      mod_methods_txt.each do |method_txt|
        test_file = "#{folder}/#{method_txt}_spec.rb"
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
          modified, txt = create_test(mod_txt, method_txt, mod_obj.method(method_txt),test_txt)
          File.open(test_file, "w") { |file| file.write(txt) }
          `rufo #{test_file}`
          if test_txt == ""
            message = "- Test created: #{test_file}"
          elsif modified
            message = "- Test updated: #{test_file}"
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
      File.open(helper_file, "w") { |file| file.write(create_helper(@params, helper_txt)) }
      message = "- Helper: #{helper_file}"
      @logger.info message
      puts message
      `rufo #{helper_file}`
    end


  end

  class << self
    # Returns array with the modules that include the http methods
    # fex: ['Swagger::UberApi::V1_0_0::Products', 'Swagger::UberApi::V1_0_0::Cities']
    private def get_modules(mod)
      modules = []
      mod = eval(mod) if mod.kind_of?(String)
      mod.constants.each do |m|
        o = eval ("#{mod}::#{m}.constants")
        if o.size == 0
          modules << "#{mod}::#{m}"
        else
          modules = get_modules("#{mod}::#{m}")
        end
      end
      modules
    end

    # Create the settings file
    private def create_settings(requests_file_orig, modules_to_include)
      output = "# required libraries
        require 'nice_http'
        require 'nice_hash'
        require 'string_pattern'
        require 'pathname'

        # Root directory for the project
        ROOT_DIR = Pathname.new(__FILE__).join('..').join('..')

        # Global settings
        # in case supplied HOST=XXXXX in command line or added to ENV variables
        # fex: HOST=myhosttotest
        ENV['HOST'] ||= 'defaulthost'
        NiceHttp.host = ENV['HOST']
        # Add here the headers for authentication for example
        NiceHttp.headers = {
            Auhentication: 'Token'
        }

        # Requests
        require_relative '.#{requests_file_orig}'\n
        require_relative '../spec/helper.rb'\n"

      modules_to_include.each do |m|
        output += "include #{m}\n"
      end
      output
    end

    # Create the helper file
    private def create_helper(params, helper_txt)
      if helper_txt == ""
        output = "# for the case we want to use it standalone, not inside the project
                    require '../settings/general' unless defined?(ROOT_DIR)
        
                    # On the methods you can pass the active http connection or none, then it will be created a new one.
                    # Examples from tests:
                    #   Helper.the_method_i_call(@http)
                    #   Helper.the_method_i_call()
                    module Helper\n"
      else
        output = helper_txt
        output.gsub!(/\s*end\s*\Z/,"\n")
      end

      params.each do |p|
        unless output.include?("def self.#{p.gsub("@","")}(")
          @logger.info "= Helper: added method #{p.gsub("@","")}" unless helper_txt == ""
          output += "def self.#{p.gsub("@","")}(http = NiceHttp.new())\n"
          output += 'http.logger.info "Helper.#{__method__}"'
          output += "\n\n"
          output += "return ''"
          output += "end\n"
        end
      end

      output += "\nend"

    end

    # Return true or false and the test source code
    private def create_test(module_txt, method_txt, method_obj, test_txt)
      modified = false      
      mod_name = module_txt.scan(/::(\w+)$/).join
      req_txt = "#{method_txt}("
      params = []
      method_obj.parameters.each do |p|
        if p[0] == :req #required
          params << "@#{p[1]}"
        end
      end
      req_txt += params.join(", ")
      req_txt += ")"
      request = eval("#{module_txt}.#{req_txt}")

      req_txt = "#{mod_name}.#{req_txt}"
      params_declaration_txt = ""
      ## todo: add param in case of :append 
      params.each do |p|
        params_declaration_txt << "#{p} = Helper.#{p.gsub('@','')}(@http)\n"
        @params << p
      end

      if test_txt ==""
        modified = true
        output = "
        require_relative '../../settings/general'

        RSpec.describe #{mod_name}, '##{method_txt}' do
        before(:all) do
          # create connection on default host and store the logs on the_name_of_file.rb.log
          @http = NiceHttp.new({log: \"\#{__FILE__}.log\"})
          #{params_declaration_txt}@request = #{req_txt}
        end
        before(:each) do |example|
            @http.logger.info(\"\\n\\n\#{'='*100}\\nTest: \#{example.description}\\n\#{'-'*100}\")
        end\n"
      else
        output = test_txt
        output.gsub!(/\s*end\s*\Z/,"\n")
      end


      tests = Hash.new()

      # first response on responses is the one expected to be returned when success
      if request.key?(:responses) and request[:responses].size > 0
        code = request[:responses].keys[0]
        title="it 'has correct structure in succesful response' "
        tests[title] = "do
                resp = @http.#{request[:method]}(@request)
                expect(resp.code).to eq #{code}\n"

        if request[:responses][code].is_a?(Hash) and request[:responses][code].key?(:data)
          tests[title] +="expect(NiceHash.compare_structure(@request.responses._#{code}.data, resp.data.json, true)).to be true\n"
        end
        tests[title] += "end\n"
      end

      title = "it 'doesn\\'t retrieve data if not authenticated'"
      tests[title] = "do
            http = NiceHttp.new()
            http.logger = @http.logger
            http.headers = {}
            resp = @http.#{request[:method]}(@request)
            expect(resp.code).to be_between('400', '499')\n"
      if request.key?(:responses) and (request[:responses].keys.select{|c| c.to_s.to_i>=400&&c.to_s.to_i<=499}).size>0
      tests[title] += "expect(NiceHash.compare_structure(@request.responses[resp.code.to_sym].data, resp.data.json)).to eq true
        expect(resp.message).to eq @request.responses[resp.code.to_sym].message\n"
      end
      tests[title] += "end\n"
            
      if params.size > 0
        missing_param = ""
        params.each do |p|
          r = req_txt.gsub(/#{p}([),])/, '""\1')
          missing_param += "
                    request = #{r}
                    resp = @http.#{request[:method]}(request)
                    expect(resp.code).to be_between('400', '499')\n"
                    if request.key?(:responses) and (request[:responses].keys.select{|c| c.to_s.to_i>=400&&c.to_s.to_i<=499}).size>0
                      missing_param += "expect(resp.message).to match /\#{request.responses[resp.code.to_sym].message}/i\n"
                    end
        end
        missing_param += "end\n"
        tests["it 'returns error if required parameter missing' "] = "do\n#{missing_param}"
      end

      if request.key?(:data) and request.key?(:data_required)
        missing_param_data = ""
        missing_param_data += "
                @request[:data_required].each do |p|
                    @request.values_for = { p => '' }
                    resp = @http.#{request[:method]}(@request)
                    expect(resp.code).not_to be_between('200', '299')
                    if @request.responses.key?(resp.code.to_sym)
                    expect(resp.message).to match /\#{@request.responses[resp.code.to_sym].message}/i
                    end
                end
            "
        missing_param_data += "end\n"
        tests["it 'returns error if required parameter on data missing' do\n"] = missing_param_data
      end

      tests.each do |k,v|
        unless output.include?(k.gsub(" '",' "').gsub("' ",'" ')) or 
          output.include?(k.gsub(' "'," '").gsub('" ',"' "))
          modified = true
          message = " = test added #{k} for #{method_txt}"
          @logger.info message
          puts message unless test_txt == ''
          output += "#{k}#{v}"
        end
      end
      output += "\nend"
      return modified, output
    end
  end
end