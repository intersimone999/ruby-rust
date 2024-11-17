require_relative '../core'
require_relative '../stats/descriptive'
require_relative '../stats/correlation'

module Rust::Models
end

##
# Contains classes that allow to run regression models.

module Rust::Models::Regression
    
    ##
    # Generic regression model in R.
    
    class RegressionModel < Rust::RustDatatype
        
        attr_accessor :data
        attr_accessor :dependent_variable
        attr_accessor :options
        
        def self.can_pull?(type, klass)
            # Can only pull specific sub-types
            return false
        end
        
        def load_in_r_as(variable_name)
            @model.load_in_r_as(variable_name)
        end

        ##
        # Generates a new regression model. +object_type+ is the Ruby class of the model object; +model_type+ represents 
        # the type of model at hand; +dependent_variable+ and +independent_variables+ are directly used as part of the 
        # model formula. +data+ represents the dataset to be used. +options+ can be specified and directly passed to the
        # model.
        
        def self.generate(object_type, model_type, dependent_variable, independent_variables, data, **options)
            mapped = ""
            if options.size > 0
                mapped = options.map { |k, v| "#{k}=#{v}" }.join(", ")
                mapped = ", " + mapped
            end
            
            formula = Rust::Formula.new(dependent_variable, independent_variables.join(" + "))
            
            result = nil
            Rust.exclusive do
                Rust["#{model_type}.data"] = data
                
                Rust._eval("#{model_type}.model.result <- #{model_type}(#{formula.to_R}, data=#{model_type}.data#{mapped})")
                result = Rust["#{model_type}.model.result"]
                
                raise "An error occurred while building the model" unless result
                
                result.r_mirror_to("#{model_type}.model.result")
            end
            
            result.dependent_variable = dependent_variable
            result.data = data
            result.options = options
            
            return result
        end
        
        ##
        # Creates a new model based on +model+.
            
        def initialize(model)
            raise "Expected a R list, given a #{model.class}" if !model.is_a?(Rust::List)
            @model = model
        end
        
        def model
            @model
        end
        
        ##
        # Returns the residuals of the model.
        
        def residuals
            Rust.exclusive do
                @residuals = Rust["residuals(#{self.r_mirror})"] unless @residuals
            end
            
            return @residuals
        end
        
        ##
        # Returns the fitted values of the model.
        
        def fitted
            Rust.exclusive do
                @fitted = Rust["fitted(#{self.r_mirror})"] unless @fitted
            end
            
            return @fitted
        end
        
        ##
        # Returns the actual values in the dataset.
        
        def actuals            
            return self.fitted.zip(self.residuals).map { |couple| couple.sum }
        end
        
        ##
        # Returns the r-squared of the model.
        
        def r_2
            return self.summary|"r.squared"
        end
        
        ##
        # Returns the adjusted r-squared of the model.
        
        def r_2_adjusted
            return self.summary|"adj.r.squared"
        end
        
        ##
        # Returns the mean squared error of the model.
        
        def mse
            Rust::Descriptive.variance(self.residuals)
        end
        
        ##
        # Returns the coefficients of the model.
        
        def coefficients
            a = self.summary|"coefficients"
        end
        
        ##
        # Returns object variables for the model with basic data (coefficients and p-values). Use the method `coefficients`
        # to get more data.
        
        def variables
            unless @variables
                coefficients = self.coefficients
                
                @variables = coefficients.rownames.map do |name|
                    ModelVariable.new(name, coefficients[name, "Estimate"], coefficients[name, "Pr(>|t|)"])
                end
            end
            
            return @variables
        end
        
        ##
        # Returns only the significant variables as ModelVariable instances. See the method `variables`.
        
        def significant_variables(a = 0.05)
            self.variables.select { |v| v.significant?(a) }
        end
        
        ##
        # Runs backward selection (recursively removes a variable until the best model is found).
        # Returns both the best model and the list of excluded variable at each step
        # Note: Not fully tested
        
        def backward_selection(excluded = [])
            candidates = self.variables.select { |v| !v.intercept? && !v.significant? }.sort_by { |v| v.pvalue }.reverse
            all = self.variables.select { |v| !v.intercept? }
            
            candidates.each do |candidate|
                new_model = RegressionModel.generate(
                    self.class,
                    self.class.r_model_name,
                    self.dependent_variable,
                    (all - [candidate]).map { |v| v.name },
                    self.data,
                    **self.options
                )
                
                if new_model.r_2_adjusted >= self.r_2_adjusted
                    puts "Excluded #{candidate}" if Rust.debug?
                    return *new_model.backward_selection(excluded + [candidate])
                end
            end
            
            return self, excluded
        end
        
        
        def method_missing(name, *args)
            return model|name.to_s
        end
        
        ##
        # Returns a summary for the model using the summary function in R.
        
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
    
    ##
    # Represents a linear regression model in R.
    
    class LinearRegressionModel < RegressionModel
        def self.can_pull?(type, klass)
            return type == "list" && klass == self.r_model_name
        end
        
        def self.pull_priority
            1
        end
        
        def self.pull_variable(variable, type, klass)
            model = Rust::RustDatatype.pull_variable(variable, Rust::List)
            
            return LinearRegressionModel.new(model)
        end
        
        def self.r_model_name
            "lm"
        end
        
        ##
        # Generates a linear regression model, given its +dependent_variable+ and +independent_variables+ and its +data+. 
        # +options+ can be specified and directly passed to the model. 
        
        def self.generate(dependent_variable, independent_variables, data, **options)
            RegressionModel.generate(
                LinearRegressionModel,
                self.r_model_name, 
                dependent_variable, 
                independent_variables, 
                data, 
                **options
            )
        end
    end
    
    ##
    # Represents a linear mixed effects model in R.
    
    class LinearMixedEffectsModel < RegressionModel
        def self.can_pull?(type, klass)
            return type == "S4" && klass == self.r_model_name
        end
        
        def self.pull_priority
            1
        end
        
        def self.r_model_name
            "lmerModLmerTest"
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
        
        ##
        # Generates a linear mixed effects model, given its +dependent_variable+ and +independent_variables+ and its +data+. 
        # +options+ can be specified and directly passed to the model. 
        
        def self.generate(dependent_variable, fixed_effects, random_effects, data, **options)
            Rust.prerequisite("lmerTest")
            Rust.prerequisite("rsq")
            
            random_effects = random_effects.map { |effect| "(1|#{effect})" }
            
            RegressionModel.generate(
                LinearMixedEffectsModel,
                self.r_model_name, 
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
    
    ##
    # Slim representation for a variable in a model, with just the variable name, its coefficient and its p-value.
    
    class ModelVariable
        attr_accessor   :name
        attr_accessor   :coefficient
        attr_accessor   :pvalue
        
        def initialize(name, coefficient, pvalue)
            @name = name
            @coefficient = coefficient
            @pvalue = pvalue
        end
        
        def intercept?
            @name == "(Intercept)"
        end
        
        ##
        # Checks whether the variable is significant w.r.t. a given +a+ (0.05 by default)
        
        def significant?(a = 0.05)
            @pvalue <= a
        end
    end
end

module Rust::RBindings
    def lm(formula, data, **options)
        independent = formula.right_part.split("+").map { |v| v.strip }
        return Rust::Models::Regression::LinearRegressionModel.generate(formula.left_part, independent, data, **options)
    end
    
    def lmer(formula, data, **options)
        independent = formula.right_part.split("+").map { |v| v.strip }
        
        Rust::Models::Regression::RegressionModel.generate(
            LinearMixedEffectsModel,
            "lmer", 
            formula.left_part, 
            independent, 
            data,
            **options
        )
    end
end
