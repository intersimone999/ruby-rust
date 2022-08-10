require_relative 'datatype'

module Rust
    
    ##
    # Mirror of the formula type in R.
    
    class Formula < RustDatatype
        def self.can_pull?(type, klass)
            return klass == "formula" || (klass.is_a?(Array) && klass.include?("formula"))
        end
        
        def self.pull_variable(variable, type, klass)
            formula_elements = Rust._pull("as.character(#{variable})")

            assert("The number of elements of a formula must be 2 or 3: #{formula_elements} given") { formula_elements.size > 1 && formula_elements.size < 4 }
            if formula_elements.size == 2
               return Formula.new(nil, formula_elements[1]) 
            elsif formula_elements.size == 3
                return Formula.new(formula_elements[2], formula_elements[1])
            end
        end
        
        def load_in_r_as(variable_name)
            Rust._eval("#{variable_name} <- #{self.left_part} ~ #{self.right_part}")
        end
        
        attr_reader     :left_part
        attr_reader     :right_part
        
        ##
        # Creates a new formula with a given +left_part+ (optional) and +right_part+ (as strings). 
        
        def initialize(left_part, right_part)
            raise ArgumentError, "Expected string" if left_part && !left_part.is_a?(String)
            raise ArgumentError, "Expected string" if !right_part.is_a?(String)
            
            @left_part  = left_part || ""
            @right_part = right_part
        end
        
        def ==(oth)
            return false unless oth.is_a?(Formula)
            
            return @left_part == oth.left_part && @right_part == oth.right_part
        end
        
        def to_R
            return "#@left_part ~ #@right_part"
        end
        
        def inspect
            return self.to_R.strip
        end
    end
    
    ##
    # Mirror of the call type in R.
    
    class Call < RustDatatype
        def self.can_pull?(type, klass)
            return klass == "call"
        end
        
        def self.pull_variable(variable, type, klass)
            return Call.new(Rust["deparse(#{variable})"])
        end
        
        def load_in_r_as(variable_name)
            Rust["call.str"] = @value
            Rust._eval("#{variable_name} <- str2lang(call.str)")
        end
        
        ##
        # Creates a new call with the given +value+ (String).
        
        def initialize(value)
            @value = value
        end
        
        def value
            @value
        end
        
        def inspect
            @value
        end
    end
    
    ##
    # Mirror of the environment type in R. Currently not supported.
    
    class Environment < RustDatatype
        def self.can_pull?(type, klass)
            return type == "environment" && klass == "environment"
        end
        
        def self.pull_variable(variable, type, klass)
            warn "Exchanging R environments is not supported!"
            return Environment.new
        end
        
        def self.load_in_r_as(variable)
            warn "Exchanging R environments is not supported!"
            Rust._eval("#{variable} <- environment()")
        end
    end
    
    ##
    # Represents a function call in R. After having set up its name (constructor) and, optionally, its arguments
    # and options, it can be used the call method to execute it in the R environment.
    
    class Function
        attr_reader     :name
        attr_reader     :arguments
        attr_reader     :options
        
        ##
        # Creates a new function with a given +name+.
        
        def initialize(name)
            @function = name
            @arguments  = Arguments.new
            @options    = Options.new
        end
        
        ##
        # Sets the +options+ (Options type) of the function.
        
        def options=(options)
            raise TypeError, "Expected Options" unless options.is_a?(Options)
            
            @options = options
        end
        
        ##
        # Sets the +arguments+ (Arguments type) of the function.
        
        def arguments=(arguments)
            raise TypeError, "Expected Arguments" unless options.is_a?(Arguments)
            
            @arguments = arguments
        end
        
        def to_R
            params = [@arguments.to_R, @options.to_R].select { |v| v != "" }.join(",")
            return "#@function(#{params})"
        end
        
        ##
        # Calls the function in the R environment.
        
        def call
            Rust._eval(self.to_R)
        end
    end
    
    ##
    # Represents an R variable.
    
    class Variable
        ##
        # Creates a variable with the given +name+.
        
        def initialize(name)
            @name = name
        end
        
        def to_R
            @name
        end
    end
    
    ##
    # Represents the arguments of a function in R. Works as an Array of objects.
    
    class Arguments < Array
        def to_R
            return self.map { |v| v.to_R }.join(", ")
        end
    end
    
    ##
    # Represents the options of a function in R. Works as a Hash associating option names to objects.
    
    class Options < Hash
        def to_R
            return self.map { |k, v| "#{k}=#{v.to_R}" }.join(", ")
        end
        
        def self.from_hash(hash)
            options = Options.new
            hash.each do |key, value|
                options[key.to_s] = value
            end
            return options
        end
    end
end 
