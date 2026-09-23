
class CreateTests

  class << self

    # Return true or false and the test source code
    private def create_test(module_txt, method_txt, method_obj, test_txt, settings_relative_path: '../../settings/general', cleanup: :after_all)
      unless cleanup == false || [:after_all, :after_each].include?(cleanup)
        message = "** Wrong cleanup parameter: #{cleanup}"
        raise message
      end

      modified = false      
      mod_name = module_txt.scan(/::(\w+)$/).join
      req_txt = "#{method_txt}("
      params = []
      keywords_required = []
      method_obj.parameters.each do |p|
        if p[0] == :req #required
          params << "@#{p[1]}"
        elsif p[0] == :key and p[1].to_s.match?(/^[a-z]/i) and Object.const_defined?(p[1].to_s.upcase)
          keywords_required << p[1]
        end
      end
      req_txt += params.join(", ")
      req_txt += ")"
      require 'nice_hash'
      request = method_obj.call(*Array.new(params.size))

      req_txt = "#{mod_name}.#{req_txt}"
      params_declaration_txt = ""
      ## todo: add param in case of :append 
      params.each do |p|
        params_declaration_txt << "#{p} = Helper.#{p.gsub('@','')}(@http)\n"
        @params << p
      end

      all_params_for_chain = params + keywords_required.map { |k| "@#{k}" }
      resource_chain, target_resource = extract_resource_chain(request, all_params_for_chain)
      @setup_cleanup_resources ||= []
      @setup_cleanup_resources.concat(resource_chain) unless resource_chain.empty?
      @setup_cleanup_resources << target_resource if target_resource

      is_delete = request[:method] == :delete
      needs_target_setup = target_resource && [:delete, :get, :patch].include?(request[:method])
      parent_resource = resource_chain.last

      method_suffix = method_txt.to_s.split("_").map { |w| w[0..2] }.join[0..2]
      method_suffix = "-#{method_suffix}"

      setup_before_all_txt = ""
      setup_before_each_txt = ""
      after_each_txt = ""
      after_all_txt = ""

      if is_delete && target_resource && parent_resource
        setup_before_all_txt = "expect(Helper.setup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')}).state).to eq 'Succeeded'\n"
        setup_before_each_txt = "expect(Helper.setup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')}).state).to eq 'Succeeded'\n"
        if cleanup
          after_each_txt = "after(:each) do\nHelper.cleanup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')})\nend\n"
          after_all_txt = "after(:all) do\nunless defined?(DONT_DELETE) && DONT_DELETE\nHelper.cleanup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')})\nend\nend\n"
        end
      elsif needs_target_setup && target_resource
        setup_before_all_txt = "expect(Helper.setup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')}).state).to eq 'Succeeded'\n"
        if cleanup
          after_all_txt = "after(:all) do\nunless defined?(DONT_DELETE) && DONT_DELETE\nHelper.cleanup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')})\nend\nend\n"
        end
      elsif parent_resource
        setup_before_all_txt = "expect(Helper.setup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')}).state).to eq 'Succeeded'\n"
        if cleanup && target_resource
          after_each_txt = "after(:each) do\nHelper.cleanup_#{target_resource[:resource]}(@http, #{target_resource[:params_up_to].join(', ')})\nend\n"
          after_all_txt = "after(:all) do\nunless defined?(DONT_DELETE) && DONT_DELETE\nHelper.cleanup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')})\nend\nend\n"
        elsif cleanup
          after_all_txt = "after(:all) do\nunless defined?(DONT_DELETE) && DONT_DELETE\nHelper.cleanup_#{parent_resource[:resource]}(@http, #{parent_resource[:params_up_to].join(', ')})\nend\nend\n"
        end
      end

      if cleanup == :after_each && !after_all_txt.empty?
        after_each_txt += after_all_txt.sub("after(:all)", "after(:each)")
        after_all_txt = ""
      end

      if test_txt ==""
        modified = true

        suffix_txt = ""
        if target_resource
          target_param = target_resource[:params_up_to].last
          suffix_txt = "#{target_param} = #{target_param} + \"#{method_suffix}\"\n"
        end

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
      else
        output = test_txt
        if output.match?(/\s*end\s*end\s*end\s*\Z/)
          output.gsub!(/\s*end\s*end\s*\Z/,"\n")
        else
          output.gsub!(/\s*end\s*\Z/,"\n")
        end
      end


      tests = Hash.new()

      # first response on responses is the one expected to be returned when success
      if request.key?(:responses) and request[:responses].size > 0
        code = request[:responses].keys[0]
        title="it 'has correct structure in successful response' "
        tests[title] = "do
                resp = @http.#{request[:method]}(@request)
                expect(resp.code).to eq #{code}\n"

        if request[:responses][code].is_a?(Hash) and request[:responses][code].key?(:data)
          tests[title] +="result = NiceHttp.validate_response(resp, @request.responses._#{code}.data, include_diff: true)\n"
          tests[title] +="expect(result[:ok]).to be(true), \"Structure mismatch: \#{result[:diff]}\"\n"
        end
        tests[title] += "end\n"
      end

      title = "it 'doesn\\'t retrieve data if not authenticated'"
      tests[title] = "do
            http = NiceHttp.new()
            http.headers = {}
            resp = http.#{request[:method]}(@request)
            expect(resp.code).to be_between('400', '499')\n"
      if request.key?(:responses) and (request[:responses].keys.select{|c| c.to_s.to_i>=400&&c.to_s.to_i<=499}).size>0
      tests[title] += "expect(NiceHash.compare_structure(@request.responses[resp.code.to_sym].data, resp.data.json)).to eq true
        expect(resp.message).to eq @request.responses[resp.code.to_sym].message\n"
      end
      tests[title] += "end\n"
            
      if params.size > 0 or keywords_required.size >0
        empty_param = ""
        params.each do |p|
          r = req_txt.gsub(/#{p}([),])/, '""\1')
          empty_param += "
                    request = #{r}
                    resp = @http.#{request[:method]}(request)
                    expect(resp.code).to be_between('400', '499')\n"
                    if request.key?(:responses) and (request[:responses].keys.select{|c| c.to_s.to_i>=400&&c.to_s.to_i<=499}).size>0
                      empty_param += "expect(resp.message).to match /\#{request.responses[resp.code.to_sym].message}/i\n"
                    end
        end
        if keywords_required.size > 0 
          r = req_txt.scan(/(.+)\(/).join
          empty_param += "
                    [:#{keywords_required.join(', :')}].each do |kw|
                      request = #{r}(kw => '')
                      resp = @http.#{request[:method]}(request)
                      expect(resp.code).to be_between('400', '499')\n"
          if request.key?(:responses) and (request[:responses].keys.select{|c| c.to_s.to_i>=400&&c.to_s.to_i<=499}).size>0
            empty_param += "expect(resp.message).to match /\#{request.responses[resp.code.to_sym].message}/i\n"
          end
          empty_param += "end\n"
        end
        empty_param += "end\n"
        tests["it 'returns error if required parameter empty' "] = "do\n#{empty_param}"
      end

      if request.key?(:mock_response)
        title = "it 'returns expected mock response' "
        tests[title] = "do
                @http_mock = NiceHttp.new()
                @http_mock.use_mocks = true
                resp = @http_mock.#{request[:method]}(@request)
                expect(resp.code).to eq @request[:mock_response][:code]
                expect(resp.message).to eq @request[:mock_response][:message]\n"
        if request[:mock_response].key?(:data)
          tests[title] += "expect(NiceHash.compare_structure(@request[:mock_response][:data], resp.data.json, true)).to be true\n"
        end
        tests[title] += "end\n"
      end

      if request.key?(:data) and [:post, :put, :patch].include?(request[:method])
        title = "it 'handles multiple valid data variations' "
        tests[title] = "do
                @request[:data].generate_n(5, :correct).each do |generated_data|
                  request = @request.deep_copy
                  request[:data] = generated_data
                  resp = @http.#{request[:method]}(request)
                  expect(resp.code.to_i).to be_between(200, 299)
                end
              end\n"
      end

      if request.key?(:data)
        title = "it 'returns error when individual data fields are invalid' "
        tests[title] = "do
                wrong = @request[:data].generate(:correct, errors: :min_length)
                NiceHash.change_one_by_one([@request[:data], :correct], wrong).each do |one_wrong|
                  request = @request.deep_copy
                  request[:data] = one_wrong
                  resp = @http.#{request[:method]}(request)
                  expect(resp.code.to_i).not_to be_between(200, 299)
                end
              end\n"
      end

      if request.key?(:data) and request.key?(:data_required)
        empty_param_data = ""
        empty_param_data += "
                @request[:data_required].each do |p|
                  request = @request.deep_copy
                  request.values_for[p] = ''
                  resp = @http.#{request[:method]}(request)
                  expect(resp.code).not_to be_between('200', '299')
                    if request.responses.key?(resp.code.to_sym)
                      expect(resp.message).to match /\#{request.responses[resp.code.to_sym].message}/i
                    end
                end
            "
        empty_param_data += "end\n"
        tests["it 'returns error if required parameter on data empty' do\n"] = empty_param_data

        missing_param_data = ""
        missing_param_data += "
                @request[:data_required].each do |p|
                  request = @request.deep_copy
                  NiceHash.delete_nested(request[:data], p)
                  resp = @http.#{request[:method]}(request)
                  expect(resp.code).not_to be_between('200', '299')
                    if request.responses.key?(resp.code.to_sym)
                      expect(resp.message).to match /\#{request.responses[resp.code.to_sym].message}/i
                    end
                end
            "
        missing_param_data += "end\n"
        tests["it 'returns error if required parameter on data missing' do\n"] = missing_param_data
      end

      tests.each do |k,v|
        unless output.include?(k.gsub(" '",' "').gsub("' ",'" ').gsub("\n",'').gsub(/\s+do$/,'').gsub(/^\s*it/,'')) or 
          output.include?(k.gsub(' "'," '").gsub('" ',"' ").gsub("\n",'').gsub(/\s+do$/,'').gsub(/^\s*it/,''))
          modified = true
          message = " = test added #{k} for #{method_txt}"
          @logger.info message
          unless test_txt == ''
            puts message
            output +="# Appended #{Time.now.stamp}\n"
          end
          output += "#{k}#{v}"
        end
      end
      if output.include?('defined?(')
        output += "\nend\nend"
      else
        output +="\nend"
      end
      return modified, output
    end
  end
end