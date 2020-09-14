require 'code-assertions'

require_relative 'rust-core'

module Rust::Descriptive
    class << self
        def mean(data)
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            
            return data.sum.to_f / data.size
        end
        
        def standard_deviation(data)
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            
            return Math.sqrt(variance(data))
        end
        alias :sd     :standard_deviation
        alias :stddev :standard_deviation
        
        def variance(data)
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            return Float::NAN if data.size < 2
            
            mean = mean(data)
            return data.map { |v| (v - mean) ** 2 }.sum.to_f / (data.size - 1)
        end
        alias :var     :variance
        
        def median(data)
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            
            sorted = data.sort
            if data.size == 0
                return Float::NAN
            elsif data.size.odd?
                return sorted[data.size / 2]
            else
                i = (data.size / 2)
                return (sorted[i - 1] + sorted[i]) / 2.0
            end
        end
        
        def sum(data)
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            
            return data.sum
        end
        
        def quantile(data, percentiles=[0.0, 0.25, 0.5, 0.75, 1.0])
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !percentiles.is_a?(Array) || !percentiles.all? { |e| e.is_a?(Numeric) }
            raise "Percentiles outside the range: #{percentiles}" if percentiles.any? { |e| !e.between?(0, 1) } 
            
            Rust.exclusive do 
                Rust['descriptive.data'] = data
                Rust['descriptive.percs'] = percentiles
                
                call_result = Rust._pull("quantile(descriptive.data, descriptive.percs)")
                assert { call_result.is_a?(Array) }
                assert { call_result.size == percentiles.size }
                
                return percentiles.zip(call_result).to_h
            end
        end
    end
end
