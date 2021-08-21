require_relative 'datatype'

module Rust
    class Factor < RustDatatype
        def self.can_pull?(type, klass)
            return klass == "factor"
        end
        
        def self.pull_variable(variable, type, klass)
            levels = Rust["levels(#{variable})"]
            values = Rust["as.integer(#{variable})"]
            
            return Factor.new(values, levels)
        end
        
        def load_in_r_as(variable_name)
            Rust['tmp.levels'] = @levels.map { |v| v.to_s }
            Rust['tmp.values'] = @values
            
            Rust._eval("#{variable_name} <- factor(tmp.values, labels=tmp.levels)")
        end
        
        def initialize(values, levels)
            @levels = levels.map { |v| v.to_sym }
            @values = values
        end
        
        def levels
            @levels
        end
        
        def ==(other)
            return false unless other.is_a?(Factor)
            
            return @levels == other.levels && self.to_a == other.to_a
        end
        
        def [](i)
            FactorValue.new(@values[i], @levels[@values[i] - 1])
        end
        
        def []=(i, value)
            raise "The given value is outside the factor bounds" if value.is_a?(Integer) && (value < 1 || value > @levels.size)
            
            if value.is_a?(FactorValue)
                raise "Incompatible factor value, different levels used" unless @levels.include?(value.level) || @levels.index(value.level) + 1 == @value.value
                value = value.value
            end
            
            if value.is_a?(String) || value.is_a?(Symbol)
                value = value.to_sym
                raise "Unsupported value #{value}; expected #{@levels.join(", ")}" unless @levels.include?(value)
                
                value = @levels.index(value) + 1
            end
            
            @values[i] = value
        end
        
        def to_a
            @values.map { |v| FactorValue.new(v, @levels[v - 1]) }
        end
        
        def method_missing(method, *args, &block)
            raise NoMethodError, "Undefined method #{method} for Factor" if method.to_s.end_with?("!") || method.end_with?("=")
            
            self.to_a.method(method).call(*args, &block)
        end
        
        def to_s
            self.to_a.to_s
        end
        
        def inspect
            self.to_a.inspect
        end
    end
    
    class FactorValue
        def initialize(value, level)
            @value = value
            @level = level
        end
        
        def value
            @value
        end
        
        def level
            @level
        end
        
        def to_i
            @value
        end
        
        def to_sym
            @level
        end
        
        def to_R
            self.to_i
        end
        
        def inspect
            @level.inspect
        end
        
        def ==(other)
            if other.is_a?(FactorValue)
                @value == other.value && @level == other.level
            elsif other.is_a?(Integer)
                @value == other
            elsif other.is_a?(Symbol)
                @level == other
            end
        end
        
        def hash
            @value.hash + @level.hash
        end
        
        def eql?(other)
            return self == other
        end
        
        def method_missing(method, *args, &block)
            @level.method(method).call(*args, &block)
        end
    end
end
