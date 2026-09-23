
class CreateTests

    class << self
  
      # Create the helper file (param stubs only).
      # chain_requires: relative paths (from the helper file) for setup/cleanup, included only when those files are generated.
      private def create_helper(params, helper_txt, settings_relative_path: '../settings/general', chain_requires: [])
        chain_lines = chain_requires.map { |rel| "require_relative '#{rel}'\n" }.join
        if helper_txt == ""
          output = "# for the case we want to use it standalone, not inside the project
                      require_relative '#{settings_relative_path}' unless defined?(ROOT_DIR)
                      #{chain_lines}
                      # On the methods you can pass the active http connection or none, then it will be created a new one.
                      # Examples from tests:
                      #   Helper.the_method_i_call(@http)
                      #   Helper.the_method_i_call()
                      module Helper\n"
        else
          output = helper_txt.dup
          missing = chain_requires.reject { |rel| output.include?("require_relative '#{rel}'") }
          unless missing.empty?
            insert = missing.map { |rel| "require_relative '#{rel}'\n" }.join
            if output.include?("module Helper")
              output.sub!("module Helper", "#{insert}module Helper")
            else
              output = insert + output
            end
          end
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

      # Generate helper/setup.rb with cascading setup methods
      private def create_setup_file(setup_cleanup_resources)
        output = "require 'ostruct'\nmodule Helper\n"

        ordered = deduplicate_resources(setup_cleanup_resources)

        ordered.each do |res|
          param_list = res[:params_up_to].map { |p| p.gsub("@", "") }.join(", ")
          parent = find_parent_resource(res, ordered)

          output += "# TODO: Create the #{res[:resource]} resource needed as prerequisite\n"
          output += "def self.setup_#{res[:resource]}(http, #{param_list})\n"
          if parent
            parent_params = parent[:params_up_to].map { |p| p.gsub("@", "") }.join(", ")
            output += "parent_result = setup_#{parent[:resource]}(http, #{parent_params})\n"
            output += "return parent_result unless parent_result[:state] == 'Succeeded'\n"
          end
          output += 'http.logger.info "Helper.#{__method__}"'
          output += "\n"
          output += "OpenStruct.new(state: 'Succeeded')\n"
          output += "end\n"
        end

        output += "\nend\n"
      end

      # Generate helper/cleanup.rb with cascading cleanup methods
      private def create_cleanup_file(setup_cleanup_resources)
        output = "module Helper\n"

        ordered = deduplicate_resources(setup_cleanup_resources)

        ordered.each do |res|
          param_list = res[:params_up_to].map { |p| p.gsub("@", "") }.join(", ")
          parent = find_parent_resource(res, ordered)

          output += "# TODO: Delete the #{res[:resource]} resource after tests\n"
          output += "def self.cleanup_#{res[:resource]}(http, #{param_list})\n"
          output += 'http.logger.info "Helper.#{__method__}"'
          output += "\n"
          if parent
            parent_params = parent[:params_up_to].map { |p| p.gsub("@", "") }.join(", ")
            output += "cleanup_#{parent[:resource]}(http, #{parent_params})\n"
          end
          output += "end\n"
        end

        output += "\nend\n"
      end

      private def deduplicate_resources(resources)
        seen = []
        resources.each_with_object([]) do |res, arr|
          next if seen.include?(res[:resource])
          seen << res[:resource]
          arr << res
        end
      end

      # Find the actual parent resource by matching params_up_to as a proper prefix
      private def find_parent_resource(resource, all_resources)
        my_params = resource[:params_up_to]
        return nil if my_params.size <= 1

        parent_params = my_params[0..-2]
        all_resources.reverse_each do |candidate|
          return candidate if candidate[:params_up_to] == parent_params
        end

        best = nil
        all_resources.each do |candidate|
          next if candidate[:resource] == resource[:resource]
          next unless candidate[:params_up_to].size < my_params.size
          next unless candidate[:params_up_to] == my_params[0, candidate[:params_up_to].size]
          if best.nil? || candidate[:params_up_to].size > best[:params_up_to].size
            best = candidate
          end
        end
        best
      end

      # Append only missing setup_/cleanup_ methods from generated content into an
      # existing file. Existing method bodies are left untouched.
      # @return [Array(String, Boolean)] merged content and whether anything was added
      private def append_missing_chain_methods(existing_txt, generated_txt)
        method_blocks = extract_chain_method_blocks(generated_txt)
        missing = method_blocks.reject { |blk| existing_txt.include?("def self.#{blk[:name]}(") }
        return [existing_txt, false] if missing.empty?

        output = existing_txt.dup
        insert = missing.map { |blk| blk[:text] }.join

        if output.match?(/\bmodule\s+Helper\b/)
          if output.match?(/\s*end\s*\Z/)
            output.sub!(/\s*end\s*\Z/, "\n#{insert}\nend\n")
          else
            output << "\n#{insert}"
          end
        else
          # Preserve leading require (e.g. ostruct) from generated content when wrapping.
          require_line = generated_txt[/^require[^\n]*\n/]
          prefix = require_line && !output.include?(require_line.strip) ? require_line : ""
          output = "#{prefix}module Helper\n#{output.chomp}\n#{insert}\nend\n"
        end

        [output, true]
      end

      private def extract_chain_method_blocks(generated_txt)
        blocks = []
        lines = generated_txt.lines
        i = 0
        while i < lines.size
          if lines[i] =~ /\A#/
            comment_start = i
            i += 1 while i < lines.size && lines[i] =~ /\A#/
            if i < lines.size && lines[i] =~ /\Adef self\.(setup_\w+|cleanup_\w+)\(/
              name = $1
              start = comment_start
              i += 1
              depth = 1
              while i < lines.size && depth > 0
                depth += 1 if lines[i] =~ /\A\s*def\b/
                depth -= 1 if lines[i] =~ /\Aend\b/
                i += 1
              end
              blocks << { name: name, text: lines[start...i].join }
              next
            end
          elsif lines[i] =~ /\Adef self\.(setup_\w+|cleanup_\w+)\(/
            name = $1
            start = i
            i += 1
            depth = 1
            while i < lines.size && depth > 0
              depth += 1 if lines[i] =~ /\A\s*def\b/
              depth -= 1 if lines[i] =~ /\Aend\b/
              i += 1
            end
            blocks << { name: name, text: lines[start...i].join }
            next
          end
          i += 1
        end
        blocks
      end
    end
  end