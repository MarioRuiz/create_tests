# required libraries
require "nice_http"
require "nice_hash"
require "string_pattern"
require "pathname"

# Root directory for the project
ROOT_DIR = Pathname.new(__FILE__).join("..").join("..")

# Global settings
# in case supplied HOST=XXXXX in command line or added to ENV variables
# fex: HOST=myhosttotest
ENV["HOST"] ||= "defaulthost"
NiceHttp.host = ENV["HOST"]
# Add here the headers for authentication for example
NiceHttp.headers = {
  Auhentication: "Token",
}

# Requests
require_relative "../requests/uber.yaml.rb"

require_relative "../spec/helper.rb"
include Swagger::UberApi::V1_0_0
