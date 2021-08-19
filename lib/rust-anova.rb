require_relative 'rust-core'

module Rust
    class ANOVAModel < RustDatatype
        def self.can_pull?(type, klass)
            return type == "list" && [klass].flatten.include?("aov")
        end
        
        def self.pull_variable(variable)
            model = Rust::List.pull_variable(variable)
            
            return ANOVAModel.new(model)
        end
        
        def load_in_r_as(variable_name)
            @model.load_in_r_as(variable_name)
        end
        
        def self.generate(formula, data, **options)
            mapped = ""
            if options.size > 0
                mapped = options.map { |k, v| "#{k}=#{v}" }.join(", ")
                mapped = ", " + mapped
            end
            
            Rust.exclusive do
                Rust["aov.data"] = data
                Rust._eval("aov.model.result <- aov(#{formula.to_R}, data=aov.data#{mapped})")
                result = ANOVAModel.new(Rust["aov.model.result"])
                result.r_mirror_to("aov.model.result")
                return result
            end
        end
        
        def initialize(model)
            @model = model
        end
        
        def model
            @model
        end
        
        def summary
            unless @summary
                Rust.exclusive do
                    Rust._eval("aov.smr <- summary(#{self.r_mirror})")
                    @summary = Rust['aov.smr']
                end
            end
            
            return @summary
        end
    end
end

module Rust::RBindings
    def aov(formula, data, **options)
        return ANOVAModel.generate(formula, data, **options)
    end
end
