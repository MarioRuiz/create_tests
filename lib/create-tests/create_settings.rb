
class CreateTests

    class << self
  
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
          NiceHttp.log = :file_run
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
    end
  end