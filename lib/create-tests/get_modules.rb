
class CreateTests

  class << self
    # Returns array with the modules that include the http methods
    # fex: ['Swagger::UberApi::V1_0_0::Products', 'Swagger::UberApi::V1_0_0::Cities']
    private def get_modules(mod)
      modules = []
      mod = eval(mod) if mod.kind_of?(String)
      mod.constants.each do |m|
        o = eval ("#{mod}::#{m}.constants")
        if o.size == 0
          modules << "#{mod}::#{m}"
        else
          modules = get_modules("#{mod}::#{m}")
        end
      end
      modules
    end
    end
end