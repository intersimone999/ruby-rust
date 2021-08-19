require_relative 'rust-core'

module Rust::Models
end

module Rust::Models::Regression
    class RegressionModel < Rust::RustDatatype
        def self.can_pull?(type, klass)
            # Can only pull specific sub-types
            return false
        end
        
        def self.pull_variable(klass, variable)
            model = Rust::List.pull_variable(variable)
            
            return klass.new(model)
        end
        
        def load_in_r_as(variable_name)
            @model.load_in_r_as(variable_name)
        end

        
        def self.generate(object_type, model_type, dependent_variable, independent_variables, data, **options)
            mapped = ""
            if options.size > 0
                mapped = options.map { |k, v| "#{k}=#{v}" }.join(", ")
                mapped = ", " + mapped
            end
            
            formula = Rust::Formula.new(dependent_variable, independent_variables.join(" + "))
            
            Rust.exclusive do
                Rust["#{model_type}.data"] = data
                
                Rust._eval("#{model_type}.model.result <- #{model_type}(#{formula.to_R}, data=#{model_type}.data#{mapped})")
                result = object_type.new(Rust["#{model_type}.model.result"])
                result.r_mirror_to("#{model_type}.model.result")
                
                return result
            end
        end
            
        def initialize(model)
            @model = model
        end
        
        def model
            @model
        end
        
        def residuals
            Rust.exclusive do
                @residuals = Rust["residuals(#{self.r_mirror})"] unless @residuals
            end
            
            return @residuals
        end
        
        def fitted
            Rust.exclusive do
                @fitted = Rust["fitted(#{self.r_mirror})"] unless @fitted
            end
            
            return @fitted
        end
        
        def r_2
            # Sum fitted and residual values to get actual values
            actuals = @fitted.zip(@residuals).map { |couple| couple.sum }
            
            return Rust::Correlation::Pearson.estimate(actuals, @fitted) ** 2
        end
        
        def mse
            Rust::Descriptive.variance(@residuals)
        end
        
        def coefficients
            a = self.summary
        end
        
        def method_missing(name, *args)
            return model|name.to_s
        end
        
        def summary
            unless @summary
                Rust.exclusive do
                    @summary = Rust["summary(#{self.r_mirror})"]
                end
            end
            
            return @summary
        end
        
        def r_hash
            @model.r_hash
        end
    end
    
    class LinearRegressionModel < RegressionModel
        def self.can_pull?(type, klass)
            return type == "list" && klass != "lm"
        end
        
        def self.pull_variable(variable)
            return RegressionModel.pull_variable(LinearRegressionModel, variable)
        end
        
        def self.generate(dependent_variable, independent_variables, data, **options)
            RegressionModel.generate(
                LinearRegressionModel,
                "lm", 
                dependent_variable, 
                independent_variables, 
                data, 
                **options
            )
        end
    end
    
    class LinearMixedEffectsModel < RegressionModel
        def self.can_pull?(type, klass)
            return type == "list" && klass != "lmer"
        end
        
        def self.pull_variable(variable)
            return RegressionModel.pull_variable(LinearMixedEffectsModel, variable)
        end
        
        def self.generate(dependent_variable, fixed_effects, random_effects, data, **options)
            random_effects = random_effects.map { |effect| "(1|#{effect})" }
            
            RegressionModel.generate(
                LinearMixedEffectsModel,
                "lmer", 
                dependent_variable, 
                fixed_effects + random_effects, 
                data, 
                **options
            )
        end
    end
end

module Rust::RBindings
    def lm(formula, data, **options)
        independent = formula.right_part.split("+").map { |v| v.strip }
        return LinearRegressionModel.generate(formula.left_part, independent, data, **options)
    end
    
    def lmer(formula, data, **options)
        independent = formula.right_part.split("+").map { |v| v.strip }
        
        RegressionModel.generate(
            LinearMixedEffectsModel,
            "lmer", 
            formula.left_part, 
            independent, 
            data,
            **options
        )
    end
end
