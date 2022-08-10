require_relative '../core'

##
# Module containing all the correlation-related statistics.

module Rust::Correlation
    
    ##
    # Pearson correlation utility methods.
    
    class Pearson
        
        ##
        # Runs the Pearson correlation test between +d1+ and +d2+.
        
        def self.test(d1, d2)
            raise TypeError, "Expecting Array of numerics" if !d1.is_a?(Array) || !d1.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !d2.is_a?(Array) || !d2.all? { |e| e.is_a?(Numeric) }
            
            Rust.exclusive do
                Rust['correlation.a'] = d1
                Rust['correlation.b'] = d2
                
                _, warnings = Rust._eval("correlation.result <- cor.test(correlation.a, correlation.b, method='p')", true)
                
                result = Result.new
                result.name             = "Pearson's product-moment correlation"
                result.statistics['t']  = Rust._pull('correlation.result$statistic')
                result.pvalue           = Rust._pull('correlation.result$p.value')
                result.correlation      = Rust._pull('correlation.result$estimate')
                result.exact            = !warnings.include?("Cannot compute exact p-value with ties")
                
                return result
            end
        end
        
        ##
        # Returns the Pearson correlation index between +d1+ and +d2+
        
        def self.estimate(d1, d2)
            self.test(d1, d2).correlation
        end
    end
    
    ##
    # Spearman correlation utility methods.
    
    class Spearman
        
        ##
        # Runs the Spearman correlation test between +d1+ and +d2+.
        
        def self.test(d1, d2)
            raise TypeError, "Expecting Array of numerics" if !d1.is_a?(Array) || !d1.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !d2.is_a?(Array) || !d2.all? { |e| e.is_a?(Numeric) }
            
            Rust.exclusive do
                Rust['correlation.a'] = d1
                Rust['correlation.b'] = d2
                
                _, warnings = Rust._eval("correlation.result <- cor.test(correlation.a, correlation.b, method='s')", true)
                
                result = Result.new
                result.name             = "Spearman's rank correlation rho"
                result.statistics['S']  = Rust._pull('correlation.result$statistic')
                result.pvalue           = Rust._pull('correlation.result$p.value')
                result.correlation      = Rust._pull('correlation.result$estimate')
                result.exact            = !warnings.include?("Cannot compute exact p-value with ties")
                
                return result
            end
        end
        
        ##
        # Returns the Spearman correlation index between +d1+ and +d2+
        
        def self.estimate(d1, d2)
            self.test(d1, d2).correlation
        end
    end
    
    ##
    # Kendall correlation utility methods.
    
    class Kendall
        
        ##
        # Runs the Kendall correlation test between +d1+ and +d2+.
        
        def self.test(d1, d2)
            raise TypeError, "Expecting Array of numerics" if !d1.is_a?(Array) || !d1.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !d2.is_a?(Array) || !d2.all? { |e| e.is_a?(Numeric) }
            
            Rust.exclusive do
                Rust['correlation.a'] = d1
                Rust['correlation.b'] = d2
                
                _, warnings = Rust._eval("correlation.result <- cor.test(correlation.a, correlation.b, method='k')", true)
                
                result = Result.new
                result.name             = "Kendall's rank correlation tau"
                result.statistics['T']  = Rust._pull('correlation.result$statistic')
                result.pvalue           = Rust._pull('correlation.result$p.value')
                result.correlation      = Rust._pull('correlation.result$estimate')
                result.exact            = !warnings.include?("Cannot compute exact p-value with ties")
                
                return result
            end
        end
        
        ##
        # Returns the Kendall correlation index between +d1+ and +d2+
        
        def self.estimate(d1, d2)
            self.test(d1, d2).correlation
        end
    end
    
    ##
    # Result of a correlation test.
    
    class Result
        attr_accessor   :name
        attr_accessor   :statistics
        attr_accessor   :pvalue
        attr_accessor   :correlation
        attr_accessor   :exact
        
        alias :estimate :correlation
        
        def initialize
            @statistics = {}
            @exact = true
        end
        
        ##
        # Returns the statistic with the specified +name+.
        
        def [](name)
            return @statistics[name.to_sym]
        end
        
        ##
        # Sets the +value+ for the the statistic with the specified +name+.
        
        def []=(name, value)
            @statistics[name.to_sym] = value
        end
                
        def to_s
            return "#{name}. Correlation = #{correlation}, P-value = #{pvalue} " +
                    (!@exact ? "P-value is not exact. " : "") + 
                    "#{ statistics.map { |k, v| k.to_s + " -> " + v.to_s  }.join(", ") }."
        end
    end
end

module Rust::RBindings
    def cor(d1, d2, **options)
        return cor_test(d1, d2, **options).correlation
    end
    
    def cor_test(d1, d2, **options)
        method = options[:method].to_s.downcase
        if "pearson".start_with?(method)
            return Rust::Correlation::Pearson.test(d1, d2)
        elsif "spearman".start_with?(method)
            return Rust::Correlation::Spearman.test(d1, d2)
        elsif "kendall".start_with?(method)
            return Rust::Correlation::Kendall.test(d1, d2)
        else
            raise "Unsupported method #{method}"
        end
    end
end
