require_relative 'rust-core'
require_relative 'rust-descriptive'
require_relative 'rust-basics'

module Rust::Models
end

module Rust::Models::Regression
    class RegressionModel < Rust::RustDatatype
        def self.can_pull?(type, klass)
            # Can only pull specific sub-types
            return false
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
                result = Rust["#{model_type}.model.result"]
                result.r_mirror_to("#{model_type}.model.result")
                
                return result
            end
        end
            
        def initialize(model)
            raise StandardError if model.is_a?(RegressionModel)
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
        
        def actuals            
            return self.fitted.zip(self.residuals).map { |couple| couple.sum }
        end
        
        def r_2
            return self.summary|"r.squared"
        end
        
        def r_2_adjusted
            return self.summary|"adj.r.squared"
        end
        
        def mse
            Rust::Descriptive.variance(self.residuals)
        end
        
        def coefficients
            a = self.summary|"coefficients"
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
            return type == "list" && klass == "lm"
        end
        
        def self.pull_variable(variable, type, klass)
            model = Rust::RustDatatype.pull_variable(variable, Rust::List)
            
            return LinearRegressionModel.new(model)
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
            return type == "S4" && klass == "lmerModLmerTest"
        end
        
        def self.pull_priority
            1
        end
        
        def self.pull_variable(variable, type, klass)
            model = Rust::RustDatatype.pull_variable(variable, Rust::S4Class)
            
            return LinearMixedEffectsModel.new(model)
        end
        
        def summary
            unless @summary
                Rust.exclusive do
                    Rust._eval("tmp.summary <- summary(#{self.r_mirror})")
                    Rust._eval("mode(tmp.summary$objClass) <- \"list\"")
                    Rust._eval("tmp.summary$logLik <- attributes(tmp.summary$logLik)")
                    @summary = Rust["tmp.summary"]
                end
            end
            
            return @summary
        end
        
        def self.generate(dependent_variable, fixed_effects, random_effects, data, **options)
            Rust.prerequisite("lmerTest")
            Rust.prerequisite("rsq")
            
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
        
        def r_2
        Rust.exclusive do
                Rust._eval("tmp.rsq <- rsq(#{self.r_mirror}, adj=F)")
                return Rust['tmp.rsq']
            end
        end
        
        def r_2_adjusted
            Rust.exclusive do
                Rust._eval("tmp.rsq <- rsq(#{self.r_mirror}, adj=T)")
                return Rust['tmp.rsq']
            end
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
