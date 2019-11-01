
class CreateTests

    class << self
  
      # Create the helper file
      private def create_helper(params, helper_txt)
        if helper_txt == ""
          output = "# for the case we want to use it standalone, not inside the project
                      require_relative '../settings/general' unless defined?(ROOT_DIR)
          
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
    end
  end