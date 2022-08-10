require_relative '../core'

class Numeric
    
    ##
    # Computes the distance between this and another number.
    
    def _rust_prob_distance(other)
        raise TypeError, "no implicit conversion of #{other.class} into Numeric" unless other.is_a? Numeric
        
        return (self - other).abs
    end
end

class Array
    
    ##
    # Computes the distance between this and another array.
    
    def _rust_prob_distance(other)
        raise TypeError, "no implicit conversion of #{other.class} into Array" unless other.is_a? Array
        
        longest, shortest = self.size > other.size ? [self, other] : [other, self]
        
        distance = 0
        for i in 0...longest.size
            distance += longest[i].to_i._rust_prob_distance(shortest[i].to_i)
        end
        
        return distance
    end
end

class String
    
    ##
    # Computes the distance between this and another string.
    
    def _rust_prob_distance(other)
        raise TypeError, "no implicit conversion of #{other.class} into String" unless other.is_a? String
        
        return self.bytes._rust_prob_distance other.bytes
    end
end

module Rust
    
    ##
    # Represents a slice of a random variable, for which no check is made in terms of cumulative probability.
    
    class RandomVariableSlice
        
        ##
        # Creates a new slice of random variable. +values+ is a hash of values associated with their probabilities.
        
        def initialize(values)
            raise TypeError, "Expected Hash" unless values.is_a?(Hash)
            
            @values = values
        end
        
        ##
        # Gets the probability of a value +v+. If +v+ is not specified, returns the cumulative probability of the whole
        # slice.
        
        def probability(v=nil)
            unless v
                return @values.values.sum
            else
                return @values[v]
            end
        end
        
        ##
        # Returns the value with the maximum probability.
        
        def ml
            @values.max_by { |k, v| v }[0]
        end
        
        ##
        # Returns the expected value for this slice.
        
        def expected
            @values.map { |k, v| k*v }.sum
        end
        
        ##
        # Returns a slice with the values that are greater than +n+.
        
        def >(n)
            self.so_that { |k| k > n }
        end
        
        ##
        # Returns a slice with the values that are greater than or equal to +n+.
        
        def >=(n)
            self.so_that { |k| k >= n }
        end
        
        ##
        # Returns a slice with the values that are lower than +n+.
        
        def <(n)
            self.so_that { |k| k < n }
        end
        
        ##
        # Returns a slice with the values that are lower than or equal to +n+.
        
        def <=(n)
            self.so_that { |k| k <= n }
        end
        
        ##
        # Returns a slice with the value +n+.
        
        def ==(n)
            self.so_that { |k| k == n }
        end
        
        ##
        # Returns a slice with the values between +a+ and +b+.
        
        def between(a, b)
            self.so_that { |k| k.between(a, b) }
        end
        
        ##
        # Returns a slice with the values for which the given block returns true.
        
        def so_that
            RandomVariableSlice.new(@values.select { |k, v| yield(k) })
        end
    end
    
    ##
    # Represents a random variable. The cumulative probability of the values must equal 1.

    class RandomVariable < RandomVariableSlice
        EPSILON = 1e-7
                
        attr_reader    :values

        ##
        # Creates a new random variable. +values+ is a hash of values associated with their probabilities.
        # +exact+ indicates whether this variable, when combined with others, should force to keep all the values, even
        # the most unlikely ones. If this is +false+ (default), the most improbable values (lower than EPSILON) are 
        # removed for efficiency reasons.
        
        def initialize(values = {0 => 1.0}, exact = false)
            @values = values
            @exact = exact
            
            raise "All the probabilities should be in the range [0, 1]" unless @values.values.all? { |v| v.between? 0, 1 }
            raise "The cumulative probability must be exactly 1 (#{@values.values.sum} instead)"        unless @values.values.sum.between? 1-EPSILON, 1+EPSILON
            
            approx!
        end

        ##
        # Returns the probability of value +v+.
        
        def probability(v)
            return @values[v].to_f
        end

        ##
        # Returns a new random variable which represents the sum of this and the +other+ random variable.
        
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
        
        ##
        # Based on the type of +arg+, either mul (product with another random variable) or rep (repeated sum) is called.
        
        def *(arg)
            if arg.is_a? Integer
                return rep(arg)
            elsif arg.is_a? RandomVariable
                return mul(arg)
            else
                raise "The argument must be an Integer or a RandomVariable"
            end
        end
        
        ##
        # Returns a new random variable which represents the product of this and the +other+ random variable.
        
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
        
        ##
        # Returns a new random variable which represents the sum of this random variable with itself +n+ times.
        
        def rep(times)
            rv = self
            (times-1).times do
                rv += self
            end
            
            return rv
        end
        
        ##
        # Makes sure that the operations yield all the values, even the most unlikely ones.
        
        def exact!
            @exact = true
        end
        
        ##
        # If this variable is not exact, the values with probability lower than EPSLION are removed.
        
        def approx!
            return if @exact
            
            to_delete = []
            @values.each do |v, probability|
                to_delete.push v if probability <= EPSILON
            end
            
            to_delete.each do |v| 
                probability = @values.delete v
                nearest = @values.keys.min_by { |k| k._rust_prob_distance v }
                @values[nearest] += probability
            end
        end
        
        ##
        # Returns a random value, according to the data distribution.
        
        def extract
            v = rand
            
            cumulative = 0
            @values.sort_by { |k, v| k }.each do |key, prob|
                cumulative += prob
                
                return key if cumulative >= v
            end
        end
        
        ##
        # Creates a random variable by partially specifying the values through +hash+. The remaining probability is 
        # attributed to +key+ (0, by default).
        
        def self.complete(hash, key=0)
            hash[key] = 1 - hash.values.sum
            return RandomVariable.new(hash)
        end
    end

    ##
    # Represents a uniform random variable.
    
    class UniformRandomVariable < RandomVariable
        
        ##
        # Creates random variables for which all the +values+ have the same probability (1 / values.size).
        
        def initialize(values, exact = false)
            super(values.map { |k| [k, 1.0 / values.size]}.to_h, exact)
        end
    end

    ##
    # Module that contains utilities for handling random variables.
    
    module Probabilities
        
        ##
        # Computes the probability of the random variable +v+.
        
        def P(v)
            if v.is_a? RandomVariableSlice
                raise "Cannot compute the probability of a random variable" if v.is_a? RandomVariable
                return v.probability
            else
                raise "Cannot compute the expected value of a #{v.class}"
            end
        end
        
        ##
        # Computes the expected value of the random variable +v+.
        
        def E(v)
            if v.is_a? RandomVariableSlice
                return v.expected
            else
                raise "Cannot compute the expected value of a #{v.class}"
            end
        end
    end
    
    ##
    # Module containing examples of commonly-used random variables.
    
    module RandomVariableExamples
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
