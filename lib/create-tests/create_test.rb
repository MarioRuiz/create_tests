
class CreateTests

  class << self

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
      request = eval("require 'nice_hash';#{module_txt}.#{req_txt}")

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
          @http = NiceHttp.new()
          #{params_declaration_txt}@request = #{req_txt}
          @http.logger.info(\"\\n\#{'+'*50} Before All ends \#{'+'*50}\")
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
        title="it 'has correct structure in successful response' "
        tests[title] = "do
                resp = @http.#{request[:method]}(@request)
                expect(resp.code).to eq #{code}\n"

        if request[:responses][code].is_a?(Hash) and request[:responses][code].key?(:data)
          if request.key?(:data_pattern)
            tests[title] +="expect(NiceHash.compare_structure(@request.responses._#{code}.data, resp.data.json, true, @request.data_pattern)).to be true\n"
          else
            tests[title] +="expect(NiceHash.compare_structure(@request.responses._#{code}.data, resp.data.json, true)).to be true\n"
          end
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
            
      if params.size > 0
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
        empty_param += "end\n"
        tests["it 'returns error if required parameter empty' "] = "do\n#{empty_param}"
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
      output += "\nend"
      return modified, output
    end
  end
end