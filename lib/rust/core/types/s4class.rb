require_relative 'datatype'

module Rust
    
    ##
    # Mirror for the S4 class in R.
    
    class S4Class < RustDatatype
        def self.can_pull?(type, klass)
            return type == "S4"
        end
        
        def self.pull_variable(variable, type, klass)
            slots = [Rust._pull("names(getSlots(\"#{klass}\"))")].flatten
            
            return S4Class.new(variable, klass, slots)
        end
        
        def load_in_r_as(variable_name)
            Rust._eval("#{variable_name} <- #{self.r_mirror}")
        end
        
        def r_hash
            "immutable"
        end
        
        ##
        # Creates a new S4 element, given its +variable_name+, class name (+klass+), and +slots+.
        
        def initialize(variable_name, klass, slots)
            @klass = klass
            @slots = slots
            
            self.r_mirror_to(variable_name)
        end
        
        ##
        # Returns the slot +key+ for the class name (+klass+).
        
        def [](key)
            raise ArgumentError, "Unknown slot `#{key}` for class `#@klass`" unless @slots.include?(key)
            
            Rust.exclusive do
                return Rust["#{self.r_mirror}@#{key}"]
            end
        end
        alias :| :[]
        
        ##
        # Returns the slot +key+ for the class name (+klass+) with +value+.
        
        def []=(key, value)
            raise ArgumentError, "Unknown slot `#{key}` for class `#@klass`" unless @slots.include?(key)
            
            Rust.exclusive do
                return Rust["#{self.r_mirror}@#{key}"] = value
            end
        end
        
        ##
        # Returns the slots.
        
        def slots
            @slots
        end
        
        ##
        # Returns the class name.
        
        def class_name
            @klass
        end
        
        def inspect
            return "<S4 instance of #@klass, with slots #@slots>"
        end
    end
end
