require_relative 'datatype'

module Rust
    
    ##
    # Represents a sequence of values in R (through a call to the seq function).
    
    class Sequence < RustDatatype
        attr_reader :min
        attr_reader :max
        
        def self.can_pull?(type, klass)
            return false
        end
        
        ##
        # Creates a new sequence from +min+ to +max+ with a given +step+ (default = 1).
        
        def initialize(min, max, step=1)
            @min = min
            @max = max
            @step = step
        end
        
        ##
        # Sets the step to +step+.
        
        def step=(step)
            @step = step
            
            return self
        end
        alias :step :step=
        
        def each
            (@min..@max).step(@step) do |v|
                yield v
            end
        end
        
        def to_a
            result = []
            self.each do |v|
                result << v
            end
            return result
        end
        
        def to_R
            "seq(from=#@min, to=#@max, by=#@step)"
        end
        
        def load_in_r_as(variable_name)
            Rust._eval("#{variable_name} <- #{self.to_R}")
        end
    end
    
    class MathArray < Array
        def -(other)
            raise ArgumentError, "Expected array or numeric" if !other.is_a?(::Array) && !other.is_a?(Numeric)
            raise ArgumentError, "The two arrays must have the same size" if other.is_a?(::Array) && self.size != other.size
            
            result = self.clone
            other = [other] * self.size if other.is_a?(Numeric)
            for i in 0...self.size
                result[i] -= other[i]
            end
            
            return result
        end
        
        def *(other)
            raise ArgumentError, "Expected array or numeric" if !other.is_a?(::Array) && !other.is_a?(Numeric)
            raise ArgumentError, "The two arrays must have the same size" if other.is_a?(::Array) && self.size != other.size
            
            result = self.clone
            other = [other] * self.size if other.is_a?(Numeric)
            for i in 0...self.size
                result[i] *= other[i]
            end
            
            return result
        end
                
        def +(other)
            raise ArgumentError, "Expected array or numeric" if !other.is_a?(::Array) && !other.is_a?(Numeric)
            raise ArgumentError, "The two arrays must have the same size" if other.is_a?(::Array) && self.size != other.size
            
            result = self.clone
            other = [other] * self.size if other.is_a?(Numeric)
            for i in 0...self.size
                result[i] += other[i]
            end
            
            return result
        end
        
        def /(other) #/# <- this comment is just to recover the syntax highlighting bug in Kate
            raise ArgumentError, "Expected array or numeric" if !other.is_a?(::Array) && !other.is_a?(Numeric)
            raise ArgumentError, "The two arrays must have the same size" if other.is_a?(::Array) && self.size != other.size
            
            result = self.clone
            other = [other] * self.size if other.is_a?(Numeric)
            for i in 0...self.size
                result[i] /= other[i]
            end
            
            return result
        end
        
        def **(other)
            raise ArgumentError, "Expected numeric" if !other.is_a?(Numeric)
            
            result = self.clone
            for i in 0...self.size
                result[i] = result[i] ** other
            end
            
            return result
        end
    end
end
