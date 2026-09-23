
class CreateTests

  class << self
    # Returns array with the modules that include the http methods
    # fex: ['Swagger::UberApi::V1_0_0::Products', 'Swagger::UberApi::V1_0_0::Cities']
    private def get_modules(mod)
      modules = []
      mod = Object.const_get(mod) if mod.is_a?(String)
      mod.constants.each do |m|
        child = mod.const_get(m)
        if child.constants.empty?
          modules << "#{mod}::#{m}"
        else
          modules += get_modules("#{mod}::#{m}")
        end
      end
      modules
    end
    end
end