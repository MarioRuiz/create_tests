
class CreateTests

    class << self
  
      # Create the settings file
      private def create_settings(requests_relative_path, modules_to_include, helper_relative_path: '../spec/helper.rb')
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
          NiceHttp.log = :file_run
          # Add here the headers for authentication for example
          NiceHttp.headers = {
              Authentication: 'Token'
          }
  
          # Requests
          require_relative '#{requests_relative_path}'\n
          require_relative '#{helper_relative_path}'\n"
  
        modules_to_include.each do |m|
          output += "include #{m}\n"
        end
        output
      end
    end
  end