# for the case we want to use it standalone, not inside the project
require "../settings/general" unless defined?(ROOT_DIR)

# On the methods you can pass the active http connection or none, then it will be created a new one.
# Examples from tests:
#   Helper.the_method_i_call(@http)
#   Helper.the_method_i_call()
module Helper
  def self.start_latitude(http = NiceHttp.new())
    http.logger.info "Helper.#{__method__}"

    return ""
  end
  def self.start_longitude(http = NiceHttp.new())
    http.logger.info "Helper.#{__method__}"

    return ""
  end
  def self.end_latitude(http = NiceHttp.new())
    http.logger.info "Helper.#{__method__}"

    return ""
  end
  def self.end_longitude(http = NiceHttp.new())
    http.logger.info "Helper.#{__method__}"

    return ""
  end
  def self.latitude(http = NiceHttp.new())
    http.logger.info "Helper.#{__method__}"

    return ""
  end
  def self.longitude(http = NiceHttp.new())
    http.logger.info "Helper.#{__method__}"

    return ""
  end
end
