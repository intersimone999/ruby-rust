require_relative 'rust-core'

class Numeric
    def distance(other)
        raise TypeError, "no implicit conversion of #{other.class} into Numeric" unless other.is_a? Numeric
        
        return (self - other).abs
    end
end

class Array
    def distance(other)
        raise TypeError, "no implicit conversion of #{other.class} into Array" unless other.is_a? Array
        
        longest, shortest = self.size > other.size ? [self, other] : [other, self]
        
        distance = 0
        for i in 0...longest.size
            distance += longest[i].to_i.distance(shortest[i].to_i)
        end
        
        return distance
    end
end

class String
    def distance(other)
        raise TypeError, "no implicit conversion of #{other.class} into String" unless other.is_a? String
        
        return self.bytes.distance other.bytes
    end
end

module Rust
    class RandomVariableSlice
        def initialize(values)
            raise TypeError, "Expected Hash" unless values.is_a?(Hash)
            
            @values = values
        end
        
        def probability(v=nil)
            unless v
                return @values.values.sum
            else
                return @values[v]
            end
        end
        
        def ml
            @values.max_by { |k, v| v }[0]
        end
        
        def expected
            @values.map { |k, v| k*v }.sum
        end
        
        def >(n)
            self.so_that { |k| k > n}
        end
        
        def >=(n)
            self.so_that { |k| k >= n}
        end
        
        def <(n)
            self.so_that { |k| k < n}
        end
        
        def <=(n)
            self.so_that { |k| k <= n}
        end
        
        def ==(n)
            self.so_that { |k| k == n}
        end
        
        def so_that
            RandomVariableSlice.new(@values.select { |k, v| yield(k) })
        end
        
        def between(a, b)
            RandomVariableSlice.new(@values.select { |k, v| k.between? a, b })
        end
    end

    class RandomVariable < RandomVariableSlice
        EPSILON = 1e-7
                
        attr_reader    :values

        def initialize(values = {0 => 1.0}, exact = false)
            @values = values
            @exact = exact
            
            raise "All the probabilities should be in the range [0, 1]" unless @values.values.all? { |v| v.between? 0, 1 }
            raise "The cumulative probability must be exactly 1 (#{@values.values.sum} instead)"        unless @values.values.sum.between? 1-EPSILON, 1+EPSILON
            
            approx!
        end

        def probability(v)
            return @values[v].to_f
        end

        def +(other)
        new_hash = {}
        
        @values.each do |my_key, my_value|
            other.values.each do |other_key, other_value|
                sum_key = my_key + other_key
                
                new_hash[sum_key] = new_hash[sum_key].to_f + (my_value * other_value)
            end
        end
        
        return RandomVariable.new(new_hash, @exact)
        end
        
        def *(times)
            if times.is_a? Integer
                return rep(times)
            elsif times.is_a? RandomVariable
                return mul(times)
            else
                raise "The argument must be an Integer or a RandomVariable"
            end
        end
        
        def mul(other)
            new_hash = {}
        
            @values.each do |my_key, my_value|
                other.values.each do |other_key, other_value|
                    mul_key = my_key * other_key
                    
                    new_hash[mul_key] = new_hash[mul_key].to_f + (my_value * other_value)
                end
            end
        
            return RandomVariable.new(new_hash, @exact)
        end
        
        def rep(times)
            rv = self
            (times-1).times do
                rv += self
            end
            
            return rv
        end
        
        def exact!
            @exact = true
        end
        
        def approx!
            return if @exact
            
            to_delete = []
            @values.each do |v, probability|
                to_delete.push v if probability <= EPSILON
            end
            
            to_delete.each do |v| 
                probability = @values.delete v
                nearest = @values.keys.min_by { |k| k.distance v }
                @values[nearest] += probability
            end
        end
        
        def extract
            v = rand
            
            cumulative = 0
            @values.each do |key, prob|
                cumulative += prob
                
                return key if cumulative >= v
            end
        end
        
        def self.complete(hash, key=0)
            hash[key] = 1 - hash.values.sum
            return RandomVariable.new(hash)
        end
    end

    class UniformRandomVariable < RandomVariable
        def initialize(values, exact = false)
            super(values.map { |k| [k, 1.0 / values.size]}.to_h, exact)
        end
    end

    module Probabilities
        def P(v)
            if v.is_a? RandomVariableSlice
                raise "Cannot compute the probability of a random variable" if v.is_a? RandomVariable
                return v.probability
            else
                raise "Cannot compute the expected value of a #{v.class}"
            end
        end
        
        def E(v)
            if v.is_a? RandomVariableSlice
                return v.expected
            else
                raise "Cannot compute the expected value of a #{v.class}"
            end
        end
    end
    
    class RandomVariable
        ENGLISH_ALPHABET = RandomVariable.new({
            "a" => 0.08167,
            "b" => 0.01492,
            "c" => 0.02782,
            "d" => 0.04253, 
            "e" => 0.12703, 
            "f" => 0.02228, 
            "g" => 0.02015, 
            "h" => 0.06094, 
            "i" => 0.06966, 
            "j" => 0.00153, 
            "k" => 0.00772, 
            "l" => 0.04025, 
            "m" => 0.02406, 
            "n" => 0.06749, 
            "o" => 0.07507, 
            "p" => 0.01929, 
            "q" => 0.00095, 
            "r" => 0.05987, 
            "s" => 0.06327, 
            "t" => 0.09056, 
            "u" => 0.02758, 
            "v" => 0.00978, 
            "w" => 0.02360, 
            "x" => 0.00150, 
            "y" => 0.01974, 
            "z" => 0.00074
        })
        
        DICE = UniformRandomVariable.new([1, 2, 3, 4, 5, 6])
        
        COIN = UniformRandomVariable.new(["h", "t"])
    end
end
