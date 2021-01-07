require_relative 'rust-core'

module Rust
    class Function
        attr_reader     :name
        attr_reader     :arguments
        attr_reader     :options
        
        def initialize(name)
            @function = name
            @arguments  = Arguments.new
            @options    = Options.new
        end
        
        def options=(options)
            raise TypeError, "Expected Options" unless options.is_a?(Options)
            
            @options = options
        end
        
        def arguments=(arguments)
            raise TypeError, "Expected Arguments" unless options.is_a?(Arguments)
            
            @arguments = arguments
        end
        
        def to_R
            params = [@arguments.to_R, @options.to_R].select { |v| v != "" }.join(",")
            return "#@function(#{params})"
        end
        
        def call
            Rust._eval(self.to_R)
        end
    end
    
    class SimpleFormula
        def initialize(dependent, independent)
            @dependent = dependent
            @independent = independent
        end
        
        def to_R
            return "#@dependent ~ #@independent"
        end
    end
    
    class Variable
        def initialize(name)
            @name = name
        end
        
        def to_R
            @name
        end
    end
    
    class Arguments < Array
        def to_R
            return self.map { |v| v.to_R }.join(", ")
        end
    end
    
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

module Rust::RBindings
end
