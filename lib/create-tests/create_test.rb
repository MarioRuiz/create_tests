
class CreateTests

  TEST_KINDS = %i[
    success auth required_params mock variations invalid_fields required_data
  ].freeze

  class << self

    # Return true or false and the test source code
    private def create_test(module_txt, method_txt, method_obj, test_txt, settings_relative_path: '../../settings/general', cleanup: :after_all, test: :rspec, only: nil)
      unless cleanup == false || [:after_all, :after_each].include?(cleanup)
        message = "** Wrong cleanup parameter: #{cleanup}"
        raise message
      end

      only_kinds = normalize_only(only)

      modified = false
      mod_name = module_txt.scan(/::(\w+)$/).join
      req_txt = "#{method_txt}("
      params = []
      keywords_required = []
      keyreq_kwargs = {}
      method_obj.parameters.each do |p|
        if p[0] == :req #required positional
          params << "@#{p[1]}"
        elsif p[0] == :keyreq
          keywords_required << p[1]
          keyreq_kwargs[p[1]] = nil
        elsif p[0] == :key and p[1].to_s.match?(/^[a-z]/i) and Object.const_defined?(p[1].to_s.upcase)
          # create_constants: required path/query as keyword with UPCASE constant default
          keywords_required << p[1]
        end
      end
      call_parts = params.dup
      keywords_required.each { |k| call_parts << "#{k}: @#{k}" }
      req_txt += call_parts.join(", ")
      req_txt += ")"
      require 'nice_hash'
      # Keyword-only methods (create_constants) must not receive nil positionals;
      # :keyreq needs an explicit keyword so Method#call succeeds.
      request = method_obj.call(*Array.new(params.size), **keyreq_kwargs)

      req_txt = "#{mod_name}.#{req_txt}"
      params_declaration_txt = ""
      ## todo: add param in case of :append
      params.each do |p|
        params_declaration_txt << "#{p} = Helper.#{p.gsub('@','')}(@http)\n"
        @params << p
      end
      keywords_required.each do |k|
        params_declaration_txt << "@#{k} = Helper.#{k}(@http)\n"
        @params << "@#{k}"
      end

      all_params_for_chain = params + keywords_required.map { |k| "@#{k}" }
      resource_chain, target_resource = extract_resource_chain(request, all_params_for_chain)
      @setup_cleanup_resources ||= []
      @setup_cleanup_resources.concat(resource_chain) unless resource_chain.empty?
      @setup_cleanup_resources << target_resource if target_resource

      is_delete = request[:method] == :delete
      needs_target_setup = target_resource && [:delete, :get, :patch].include?(request[:method])
      parent_resource = resource_chain.last

      method_suffix = "-#{method_txt.to_s.gsub('_', '')[0, 12]}"

      setup_before_all_txt = ""
      setup_before_each_txt = ""
      after_each_txt = ""
      after_all_txt = ""

      if is_delete && target_resource && parent_resource
        setup_before_all_txt = "#{assert_eq("Helper.setup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')}).state", "'Succeeded'", test)}\n"
        setup_before_each_txt = "#{assert_eq("Helper.setup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')}).state", "'Succeeded'", test)}\n"
        if cleanup
          after_each_txt = framework_hook(:after_each, "Helper.cleanup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')})\n", test)
          after_all_txt = framework_hook(:after_all, "unless defined?(DONT_DELETE) && DONT_DELETE\nHelper.cleanup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')})\nend\n", test)
        end
      elsif needs_target_setup && target_resource
        setup_before_all_txt = "#{assert_eq("Helper.setup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')}).state", "'Succeeded'", test)}\n"
        if cleanup
          after_all_txt = framework_hook(:after_all, "unless defined?(DONT_DELETE) && DONT_DELETE\nHelper.cleanup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')})\nend\n", test)
        end
      elsif parent_resource
        setup_before_all_txt = "#{assert_eq("Helper.setup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')}).state", "'Succeeded'", test)}\n"
        if cleanup && target_resource
          after_each_txt = framework_hook(:after_each, "Helper.cleanup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')})\n", test)
          after_all_txt = framework_hook(:after_all, "unless defined?(DONT_DELETE) && DONT_DELETE\nHelper.cleanup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')})\nend\n", test)
        elsif cleanup
          after_all_txt = framework_hook(:after_all, "unless defined?(DONT_DELETE) && DONT_DELETE\nHelper.cleanup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')})\nend\n", test)
        end
      end

      if cleanup == :after_each && !after_all_txt.empty?
        if test == :minitest
          # Minitest folds after(:all) into teardown; after_each mode just uses teardown body once.
          after_each_txt += after_all_txt
          after_all_txt = ""
        else
          after_each_txt += after_all_txt.sub("after(:all)", "after(:each)")
          after_all_txt = ""
        end
      end

      if test_txt == ""
        modified = true

        suffix_txt = ""
        if target_resource
          target_param = target_resource[:params_up_to].last
          suffix_txt = "#{target_param} = #{target_param} + \"#{method_suffix}\"\n"
        end

        if test == :minitest
          output = build_minitest_skeleton(mod_name, method_txt, settings_relative_path, params_declaration_txt, suffix_txt, setup_before_all_txt, setup_before_each_txt, after_each_txt, after_all_txt, req_txt, is_delete, target_resource)
        else
          before_each_block = "before(:each) do |example|\n"
          before_each_block << "@http = NiceHttp.new()\n" if is_delete && target_resource
          before_each_block << setup_before_each_txt
          before_each_block << "@http.logger.info(\"\\n\\n\#{'='*100}\\nTest: \#{example.description}\\n\#{'-'*100}\")\nend\n"

          output = "
        require_relative '#{settings_relative_path}'
        if defined?(#{mod_name}) and defined?(#{mod_name}.#{method_txt})
          RSpec.describe #{mod_name}, '##{method_txt}' do
          before(:all) do
            @http = NiceHttp.new()
            #{params_declaration_txt}#{suffix_txt}#{setup_before_all_txt}@request = #{req_txt}
            @http.logger.info(\"\\n\#{'+'*50} Before All ends \#{'+'*50}\")
          end
          #{after_all_txt}#{after_each_txt}#{before_each_block}\n"
        end
      else
        output = test_txt
        if test == :minitest
          output.gsub!(/\s*end\s*\Z/, "\n")
        elsif output.match?(/\s*end\s*end\s*end\s*\Z/)
          output.gsub!(/\s*end\s*end\s*\Z/, "\n")
        else
          output.gsub!(/\s*end\s*\Z/, "\n")
        end
      end


      tests = Hash.new()

      has_data_examples = request.key?(:data_examples) &&
                          request[:data_examples].is_a?(Array) &&
                          !request[:data_examples].empty?
      # Prefer data_pattern for variation/invalid-field tests; fall back to :data
      payload_source = if request.key?(:data_pattern)
                         ":data_pattern"
                       elsif request.key?(:data)
                         ":data"
                       end

      # first response on responses is the one expected to be returned when success
      if include_kind?(only_kinds, :success) && request.key?(:responses) and request[:responses].size > 0
        code = request[:responses].keys[0]
        title = example_title("has correct structure in successful response", test, trailing_space: true)
        if !request.key?(:data) && has_data_examples
          tests[title] = "do
                request = @request.deep_copy
                request[:data] = @request[:data_examples].first
                resp = @http.#{request[:method]}(request)
                #{assert_eq('resp.code', code, test)}\n"
          if request[:responses][code].is_a?(Hash) and request[:responses][code].key?(:data)
            tests[title] +="result = NiceHttp.validate_response(resp, @request.responses._#{code}.data, include_diff: true)\n"
            tests[title] += "#{assert_be_true('result[:ok]', 'Structure mismatch: #{result[:diff]}', test)}\n"
          end
          tests[title] += "end\n"
        else
          tests[title] = "do
                resp = @http.#{request[:method]}(@request)
                #{assert_eq('resp.code', code, test)}\n"

          if request[:responses][code].is_a?(Hash) and request[:responses][code].key?(:data)
            tests[title] +="result = NiceHttp.validate_response(resp, @request.responses._#{code}.data, include_diff: true)\n"
            tests[title] += "#{assert_be_true('result[:ok]', 'Structure mismatch: #{result[:diff]}', test)}\n"
          end
          tests[title] += "end\n"
        end
      end

      if include_kind?(only_kinds, :auth)
        title = example_title("doesn\\'t retrieve data if not authenticated", test)
        tests[title] = "do
            http = NiceHttp.new()
            http.headers = {}
            resp = http.#{request[:method]}(@request)
            #{assert_between('resp.code', "'400'", "'499'", test)}\n"
        if request.key?(:responses) and (request[:responses].keys.select{|c| c.to_s.to_i>=400&&c.to_s.to_i<=499}).size>0
          tests[title] += "#{assert_eq('NiceHash.compare_structure(@request.responses[resp.code.to_sym].data, resp.data.json)', 'true', test)}
        #{assert_eq('resp.message', '@request.responses[resp.code.to_sym].message', test)}\n"
        end
        tests[title] += "end\n"
      end

      if include_kind?(only_kinds, :required_params) && (params.size > 0 or keywords_required.size >0)
        empty_param = ""
        params.each do |p|
          r = req_txt.gsub(/#{p}([),])/, '""\1')
          empty_param += "
                    request = #{r}
                    resp = @http.#{request[:method]}(request)
                    #{assert_between('resp.code', "'400'", "'499'", test)}\n"
                    if request.key?(:responses) and (request[:responses].keys.select{|c| c.to_s.to_i>=400&&c.to_s.to_i<=499}).size>0
                      empty_param += "#{assert_match('resp.message', '/\#{request.responses[resp.code.to_sym].message}/i', test)}\n"
                    end
        end
        if keywords_required.size > 0
          r = req_txt.scan(/(.+)\(/).join
          empty_param += "
                    [:#{keywords_required.join(', :')}].each do |kw|
                      request = #{r}(kw => '')
                      resp = @http.#{request[:method]}(request)
                      #{assert_between('resp.code', "'400'", "'499'", test)}\n"
          if request.key?(:responses) and (request[:responses].keys.select{|c| c.to_s.to_i>=400&&c.to_s.to_i<=499}).size>0
            empty_param += "#{assert_match('resp.message', '/\#{request.responses[resp.code.to_sym].message}/i', test)}\n"
          end
          empty_param += "end\n"
        end
        empty_param += "end\n"
        tests[example_title("returns error if required parameter empty", test, trailing_space: true)] = "do\n#{empty_param}"
      end

      if include_kind?(only_kinds, :mock) && request.key?(:mock_response)
        title = example_title("returns expected mock response", test, trailing_space: true)
        tests[title] = "do
                @http_mock = NiceHttp.new()
                @http_mock.use_mocks = true
                resp = @http_mock.#{request[:method]}(@request)
                #{assert_eq('resp.code', '@request[:mock_response][:code]', test)}
                #{assert_eq('resp.message', '@request[:mock_response][:message]', test)}\n"
        if request[:mock_response].key?(:data)
          tests[title] += "#{assert_be_true('NiceHash.compare_structure(@request[:mock_response][:data], resp.data.json, true)', nil, test)}\n"
        end
        tests[title] += "end\n"
      end

      if include_kind?(only_kinds, :variations) && payload_source && [:post, :put, :patch].include?(request[:method])
        title = example_title("handles multiple valid data variations", test, trailing_space: true)
        tests[title] = "do
                @request[#{payload_source}].generate_n(5, :correct).each do |generated_data|
                  request = @request.deep_copy
                  request[:data] = generated_data
                  resp = @http.#{request[:method]}(request)
                  #{assert_between('resp.code.to_i', '200', '299', test)}
                end
              end\n"
      end

      if include_kind?(only_kinds, :invalid_fields) && payload_source
        title = example_title("returns error when individual data fields are invalid", test, trailing_space: true)
        tests[title] = "do
                wrong = @request[#{payload_source}].generate(:correct, errors: :min_length)
                NiceHash.change_one_by_one([@request[#{payload_source}], :correct], wrong).each do |one_wrong|
                  request = @request.deep_copy
                  request[:data] = one_wrong
                  resp = @http.#{request[:method]}(request)
                  #{assert_between('resp.code.to_i', '200', '299', test, negate: true)}
                end
              end\n"
      end

      if include_kind?(only_kinds, :required_data) && request.key?(:data_required) && (request.key?(:data) || has_data_examples)
        seed_data_line = if !request.key?(:data) && has_data_examples
                           "request[:data] = request[:data_examples].first\n                  "
                         else
                           ""
                         end
        empty_param_data = ""
        empty_param_data += "
                @request[:data_required].each do |p|
                  request = @request.deep_copy
                  #{seed_data_line}request.values_for[p] = ''
                  resp = @http.#{request[:method]}(request)
                  #{assert_between('resp.code', "'200'", "'299'", test, negate: true)}
                    if request.responses.key?(resp.code.to_sym)
                      #{assert_match('resp.message', '/\#{request.responses[resp.code.to_sym].message}/i', test)}
                    end
                end
            "
        empty_param_data += "end\n"
        tests[example_title("returns error if required parameter on data empty", test, with_do: true)] = empty_param_data

        missing_param_data = ""
        missing_param_data += "
                @request[:data_required].each do |p|
                  request = @request.deep_copy
                  #{seed_data_line}NiceHash.delete_nested(request[:data], p)
                  resp = @http.#{request[:method]}(request)
                  #{assert_between('resp.code', "'200'", "'299'", test, negate: true)}
                    if request.responses.key?(resp.code.to_sym)
                      #{assert_match('resp.message', '/\#{request.responses[resp.code.to_sym].message}/i', test)}
                    end
                end
            "
        missing_param_data += "end\n"
        tests[example_title("returns error if required parameter on data missing", test, with_do: true)] = missing_param_data
      end

      tests.each do |k,v|
        unless example_already_present?(output, k, test)
          modified = true
          message = " = test added #{k} for #{method_txt}"
          @logger.info message
          unless test_txt == ''
            puts message
            output +="# Appended #{Time.now.stamp}\n"
          end
          if test == :minitest
            # keys are "def test_foo" and bodies start with "do\n...\nend"
            body = v.sub(/\Ado\n/, "").sub(/\n?end\n?\z/, "\n")
            output += "#{k}\n#{body}end\n"
          else
            output += "#{k}#{v}"
          end
        end
      end
      if test == :minitest
        if output.include?('defined?(')
          output += "\nend\nend"
        else
          output += "\nend"
        end
      elsif output.include?('defined?(')
        output += "\nend\nend"
      else
        output +="\nend"
      end
      return modified, output
    end

    private def normalize_only(only)
      return nil if only.nil?
      list = case only
             when Symbol then [only]
             when String then only.split(",").map { |s| s.strip.to_sym }
             when Array then only.map { |s| s.to_s.strip.to_sym }
             else
               raise "** Wrong only parameter: #{only}"
             end
      unknown = list - TEST_KINDS
      unless unknown.empty?
        raise "** Wrong only parameter: unknown kind(s) #{unknown.join(', ')}. Valid: #{TEST_KINDS.join(', ')}"
      end
      list
    end

    private def include_kind?(only_kinds, kind)
      only_kinds.nil? || only_kinds.include?(kind)
    end

    private def example_title(description, test, trailing_space: false, with_do: false)
      if test == :minitest
        "def test_#{minitest_method_name(description)}"
      else
        space = trailing_space ? " " : ""
        if with_do
          "it '#{description}' do\n"
        else
          "it '#{description}'#{space}"
        end
      end
    end

    private def minitest_method_name(description)
      description.gsub("\\'", "")
                 .gsub(/[^a-zA-Z0-9]+/, "_")
                 .gsub(/\A_+|_+\z/, "")
                 .downcase
    end

    private def example_already_present?(output, key, test)
      if test == :minitest
        output.include?(key)
      else
        output.include?(key.gsub(" '", ' "').gsub("' ", '" ').gsub("\n", '').gsub(/\s+do$/, '').gsub(/^\s*it/, '')) ||
          output.include?(key.gsub(' "', " '").gsub('" ', "' ").gsub("\n", '').gsub(/\s+do$/, '').gsub(/^\s*it/, ''))
      end
    end

    private def assert_eq(actual, expected, test)
      if test == :minitest
        "assert_equal #{expected}, #{actual}"
      else
        "expect(#{actual}).to eq #{expected}"
      end
    end

    private def assert_be_true(actual, message, test)
      if test == :minitest
        if message
          "assert #{actual}, \"#{message}\""
        else
          "assert #{actual}"
        end
      else
        if message
          "expect(#{actual}).to be(true), \"#{message}\""
        else
          "expect(#{actual}).to be true"
        end
      end
    end

    private def assert_between(actual, low, high, test, negate: false)
      if test == :minitest
        if negate
          "refute_includes (#{low}..#{high}), #{actual}"
        else
          "assert_includes (#{low}..#{high}), #{actual}"
        end
      else
        if negate
          "expect(#{actual}).not_to be_between(#{low}, #{high})"
        else
          "expect(#{actual}).to be_between(#{low}, #{high})"
        end
      end
    end

    private def assert_match(actual, pattern, test)
      if test == :minitest
        "assert_match #{pattern}, #{actual}"
      else
        "expect(#{actual}).to match #{pattern}"
      end
    end

    private def framework_hook(kind, body, test)
      if test == :minitest
        # Stored as raw bodies; assembled into setup/teardown in the skeleton.
        # Prefix with a marker so cleanup: :after_each merging can find them.
        case kind
        when :after_each then "TEARDOWN_EACH:#{body}"
        when :after_all then "TEARDOWN_ALL:#{body}"
        else body
        end
      else
        case kind
        when :after_each then "after(:each) do\n#{body}end\n"
        when :after_all then "after(:all) do\n#{body}end\n"
        else body
        end
      end
    end

    private def build_minitest_skeleton(mod_name, method_txt, settings_relative_path, params_declaration_txt, suffix_txt, setup_before_all_txt, setup_before_each_txt, after_each_txt, after_all_txt, req_txt, is_delete, target_resource)
      class_name = "#{mod_name}#{camelize(method_txt.to_s)}Test"

      teardown_each_body = after_each_txt.to_s.gsub(/\ATEARDOWN_EACH:/, "").gsub(/\ATEARDOWN_ALL:/, "")
      # after_each_txt may contain both TEARDOWN_EACH and (after merge) TEARDOWN_ALL markers
      each_parts = []
      all_parts = []
      [after_each_txt.to_s, after_all_txt.to_s].each do |chunk|
        chunk.split(/(?=TEARDOWN_(?:EACH|ALL):)/).each do |part|
          next if part.empty?
          if part.start_with?("TEARDOWN_EACH:")
            each_parts << part.sub(/\ATEARDOWN_EACH:/, "")
          elsif part.start_with?("TEARDOWN_ALL:")
            all_parts << part.sub(/\ATEARDOWN_ALL:/, "")
          end
        end
      end

      teardown_body = (each_parts + all_parts).join

      setup_http = if is_delete && target_resource
                     "@http = NiceHttp.new()\n"
                   else
                     ""
                   end

      # before(:all) work at start of setup; before(:each) after that.
      # First test creates @http for non-delete; delete recreates in the each section.
      "
        require 'minitest/autorun'
        require_relative '#{settings_relative_path}'
        if defined?(#{mod_name}) and defined?(#{mod_name}.#{method_txt})
          class #{class_name} < Minitest::Test
          def setup
            @http = NiceHttp.new()
            #{params_declaration_txt}#{suffix_txt}#{setup_before_all_txt}@request = #{req_txt}
            @http.logger.info(\"\\n\#{'+'*50} Before All ends \#{'+'*50}\")
            #{setup_http}#{setup_before_each_txt}@http.logger.info(\"\\n\\n\#{'='*100}\\nTest: \#{name}\\n\#{'-'*100}\")
          end
          def teardown
            #{teardown_body}
          end
"
    end

    private def camelize(snake)
      snake.to_s.split("_").map(&:capitalize).join
    end
  end
end
