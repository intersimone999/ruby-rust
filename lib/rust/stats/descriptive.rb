require_relative '../core'

##
# Module containing utilities for descriptive statistics.

module Rust::Descriptive
    class << self
        
        ##
        # Computes the arithmetic mean of the given +data+.
        
        def mean(data)
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            
            return data.sum.to_f / data.size
        end
        
        ##
        # Computes the standard deviation of the given +data+.
        
        def standard_deviation(data)
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            
            return Math.sqrt(variance(data))
        end
        alias :sd     :standard_deviation
        alias :stddev :standard_deviation
        
        ##
        # Computes the variance of the given +data+.
        
        def variance(data)
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            return Float::NAN if data.size < 2
            
            mean = mean(data)
            return data.map { |v| (v - mean) ** 2 }.sum.to_f / (data.size - 1)
        end
        alias :var     :variance
        
        ##
        # Computes the median of the given +data+.
        
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
        
        ##
        # Sums the given +data+.
        
        def sum(data)
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            
            return data.sum
        end
        
        ##
        # Returns the quantiles of the given +data+, given the +percentiles+ (optional).
        
        def quantile(data, percentiles = [0.0, 0.25, 0.5, 0.75, 1.0])
            raise TypeError, "Expecting Array of numerics" if !data.is_a?(Array) || !data.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !percentiles.is_a?(Array) || !percentiles.all? { |e| e.is_a?(Numeric) }
            raise "Percentiles outside the range: #{percentiles}" if percentiles.any? { |e| !e.between?(0, 1) }
            
            n = data.size
            quantiles = percentiles.size
            percentiles = percentiles.map { |x| x > 1.0 ? 1.0 : (x < 0.0 ? 0.0 : x) }
            
            rough_indices = percentiles.map { |x| 1 + [n - 1, 0].max * x - 1 }
            floor_indices = rough_indices.map { |i| i.floor }
            ceil_indices = rough_indices.map { |i| i.ceil }
            
            data = data.sort
            result = floor_indices.map { |i| data[i] }
            result_ceil = ceil_indices.map { |i| data[i] }
            
            indices_to_fix = (0...quantiles).select { |i| rough_indices[i] > floor_indices[i] && result_ceil[i] != result[i] }
            index_approximation_errors = indices_to_fix.map { |i| rough_indices[i] - floor_indices[i] }
            reduced_index_approximation_errors = index_approximation_errors.map { |i| (1 - i) }
            hi_indices = indices_to_fix.map { |i| ceil_indices[i] }
            data_hi_indices = hi_indices.map { |i| data[i] }
            
            j = 0
            indices_to_fix.each do |i|
                result[i] = reduced_index_approximation_errors[j] * result[i] + index_approximation_errors[j] * data_hi_indices[j]
                j += 1
            end
            
            return percentiles.zip(result).to_h
        end
        
        ##
        # Returns the outliers in +data+ using Tukey's fences, with a given +k+.
        
        def outliers(data, k=1.5, **opts)
            outliers_according_to(data, data, k, **opts)
        end
        
        ##
        # Returns the outliers in +data+ using Tukey's fences, with a given +k+, with respect to different data
        # distribution (+data_distribution+).
        
        def outliers_according_to(data, data_distribution, k=1.5, **opts)
            quantiles = Rust::Descriptive.quantile(data_distribution, [0.25, 0.75])
            q1 = quantiles[0.25]
            q3 = quantiles[0.75]
            iqr = q3 - q1
            
            positive_outliers = data.select { |d| d > q3 + iqr * k }
            negative_outliers = data.select { |d| d < q1 - iqr * k }
            
            outliers = negative_outliers + positive_outliers
            if opts[:side]
                case opts[:side].to_sym
                when :positive, :neg, :n, :+
                    outliers = positive_outliers
                when :negative, :pos, :p, :-
                    outliers = negative_outliers
                end
            end
            
            return outliers
        end
    end
end

module Rust::RBindings
    def mean(series)
        Rust::Descriptive.mean(series)
    end
    
    def median(series)
        Rust::Descriptive.median(series)
    end
    
    def var(series)
        Rust::Descriptive.variance(series)
    end
    
    def sd(series)
        Rust::Descriptive.standard_deviation(series)
    end
    
    def quantile(series, percentiles = [0.0, 0.25, 0.5, 0.75, 1.0])
        Rust::Descriptive.quantile(series, percentiles)
    end
end
