require_relative 'rust-core'

module Rust::StatisticalTests
    class Result
        attr_accessor   :name
        attr_accessor   :statistics
        attr_accessor   :pvalue
        attr_accessor   :exact
        attr_accessor   :alpha
        attr_accessor   :hypothesis
        
        def initialize
            @statistics = {}
        end
        
        def [](name)
            return @statistics[name.to_sym]
        end
        
        def []=(name, value)
            @statistics[name.to_sym] = value
        end
        
        def adjusted_pvalue(method='bonferroni')
            return 1 unless @hypothesis
            @hypothesis.adjusted_pvalue_for(self, method)
        end
        
        def hypothesis=(value)
            @hypothesis = value
            @hypothesis.add(self)
        end
        
        def significant
            pvalue < alpha
        end
        
        def to_s
            return "#{name}. P-value = #{pvalue} " +
                    "(#{significant ? "significant" : "not significant"} w/ alpha = #{alpha}); " + 
                    "#{ statistics.map { |k, v| k.to_s + " -> " + v.to_s  }.join(", ") }." +
                    (!exact ? " P-value is not exact." : "")
        end
    end
    
    class Hypothesis        
        def self.find(title_or_instance)
            return Hypothesis.new(nil) if title_or_instance == nil
            
            if title_or_instance.is_a?(String)
                ObjectSpace.each_object(Hypothesis) do |instance|
                    return instance if instance.title == title_or_instance
                end
                
                return Hypothesis.new(title_or_instance)
            elsif title_or_instance.is_a?(Hypothesis)
                return title_or_instance
            end
            
            raise TypeError, "Expected nil, String or Hypothesis"
        end
        
        attr_reader :results
        attr_reader :title
        
        def initialize(title)
            @title = title
            @results = []
        end
        
        def add(result)            
            @results << result
        end
        
        def adjusted_pvalue_for(instance, method)
            p_values = @results.map { |r| r.pvalue }
            index = @results.index(instance)
            
            adjusted_pvalues = Rust::StatisticalTests::PValueAdjustment.method(method).adjust(*p_values)
            
            if adjusted_pvalues.is_a?(Numeric)
                return adjusted_pvalues
            else
                return adjusted_pvalues[index]
            end
        end
    end
end

module Rust::StatisticalTests::PValueAdjustment
    def self.method(name)
        name = name.to_s
        case name.downcase
        when "bonferroni", "b"
            return Bonferroni
        when "holm", "h"
            return Holm
        when "hochberg"
            return Hochberg
        when "hommel"
            return Hommel
        when "benjaminihochberg", "bh"
            return BenjaminiHochberg
        when "benjaminiyekutieli", "by"
            return BenjaminiYekutieli
        end
    end
    
    class Bonferroni
        def self.adjust(*p_values)
            Rust.exclusive do
                Rust['adjustment.p'] = p_values
                return Rust._pull("p.adjust(adjustment.p, method=\"bonferroni\")")
            end
        end
    end
    
    class Holm
        def self.adjust(*p_values)
            Rust.exclusive do
                Rust['adjustment.p'] = p_values
                return Rust._pull("p.adjust(adjustment.p, method=\"holm\")")
            end
        end
    end
    
    class Hochberg
        def self.adjust(*p_values)
            Rust.exclusive do
                Rust['adjustment.p'] = p_values
                return Rust._pull("p.adjust(adjustment.p, method=\"hochberg\")")
            end
        end
    end
    
    class Hommel
        def self.adjust(*p_values)
            Rust.exclusive do
                Rust['adjustment.p'] = p_values
                return Rust._pull("p.adjust(adjustment.p, method=\"hommel\")")
            end
        end
    end
    
    class BenjaminiHochberg
        def self.adjust(*p_values)
            Rust.exclusive do
                Rust['adjustment.p'] = p_values
                return Rust._pull("p.adjust(adjustment.p, method=\"BH\")")
            end
        end
    end
    
    class BenjaminiYekutieli
        def self.adjust(*p_values)
            Rust.exclusive do
                Rust['adjustment.p'] = p_values
                return Rust._pull("p.adjust(adjustment.p, method=\"BY\")")
            end
        end
    end
end

module Rust::StatisticalTests::Wilcoxon
    class << self
         def paired(d1, d2, alpha = 0.05, **options)
            raise TypeError, "Expecting Array of numerics" if !d1.is_a?(Array) || !d1.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !d2.is_a?(Array) || !d2.all? { |e| e.is_a?(Numeric) }
            raise "The two distributions have different size" if d1.size != d2.size
                        
            Rust.exclusive do
                Rust["wilcox.a"] = d1
                Rust["wilcox.b"] = d2
                
                _, warnings = Rust._eval("wilcox.result = wilcox.test(wilcox.a, wilcox.b, alternative='two.sided', paired=T)", true)
                result = Rust::StatisticalTests::Result.new
                result.name       = "Wilcoxon Signed-Rank test"
                result.pvalue     = Rust._pull("wilcox.result$p.value")
                result[:w]        = Rust._pull("wilcox.result$statistic")
                result.exact      = !warnings.include?("cannot compute exact p-value with zeroes")
                result.alpha      = alpha
                result.hypothesis = Hypothesis.find(options[:hypothesis])
            
                return result
            end
        end
        
        def unpaired(d1, d2, alpha = 0.05, **options)
            raise TypeError, "Expecting Array of numerics" if !d1.is_a?(Array) || !d1.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !d2.is_a?(Array) || !d2.all? { |e| e.is_a?(Numeric) }
            
            Rust.exclusive do
                Rust["wilcox.a"] = d1
                Rust["wilcox.b"] = d2
                
                _, warnings = Rust._eval("wilcox.result = wilcox.test(wilcox.a, wilcox.b, alternative='two.sided', paired=F)", true)
                result = Rust::StatisticalTests::Result.new
                result.name       = "Wilcoxon Ranked-Sum test (a.k.a. Mann–Whitney U test)"
                result.pvalue     = Rust._pull("wilcox.result$p.value")
                result[:w]        = Rust._pull("wilcox.result$statistic")
                result.exact      = !warnings.include?("cannot compute exact p-value with ties")
                result.alpha      = alpha
                result.hypothesis = Hypothesis.find(options[:hypothesis])
                
                return result
            end
        end
    end
end
    
module Rust::StatisticalTests::T
    class << self
        def paired(d1, d2, alpha = 0.05, **options)
            raise TypeError, "Expecting Array of numerics" if !d1.is_a?(Array) || !d1.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !d2.is_a?(Array) || !d2.all? { |e| e.is_a?(Numeric) }
            raise "The two distributions have different size" if d1.size != d2.size
            
            Rust.exclusive do
                Rust["t.a"] = d1
                Rust["t.b"] = d2
                
                warnings = Rust._eval("t.result = t.test(t.a, t.b, alternative='two.sided', paired=T)")
                result = Rust::StatisticalTests::Result.new
                result.name       = "Paired t-test"
                result.pvalue     = Rust._pull("t.result$p.value")
                result[:t]        = Rust._pull("t.result$statistic")
                result.exact      = true
                result.alpha      = alpha
                result.hypothesis = Hypothesis.find(options[:hypothesis])
                
                return result
            end
        end
        
        def unpaired(d1, d2, alpha = 0.05, **options)
            raise TypeError, "Expecting Array of numerics" if !d1.is_a?(Array) || !d1.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !d2.is_a?(Array) || !d2.all? { |e| e.is_a?(Numeric) }
            
            Rust.exclusive do
                Rust["t.a"] = d1
                Rust["t.b"] = d2
                
                Rust._eval("t.result = t.test(t.a, t.b, alternative='two.sided', paired=F)")
                result = Rust::StatisticalTests::Result.new
                result.name       = "Welch Two Sample t-test"
                result.pvalue     = Rust._pull("t.result$p.value")
                result[:t]        = Rust._pull("t.result$statistic")
                result.exact      = true
                result.alpha      = alpha
                result.hypothesis = Hypothesis.find(options[:hypothesis])
                
                return result
            end
        end
    end
end

module Rust::StatisticalTests::Shapiro
    class << self
        def compute(vector, alpha = 0.05, **options)
            raise TypeError, "Expecting Array of numerics" if !vector.is_a?(Array) || !vector.all? { |e| e.is_a?(Numeric) }
            Rust.exclusive do
                Rust['shapiro.v'] = vector
                
                Rust._eval("shapiro.result = shapiro.test(shapiro.v)")
                result = Rust::StatisticalTests::Result.new
                result.name       = "Shapiro-Wilk normality test"
                result.pvalue     = Rust._pull("shapiro.result$p.value")
                result[:W]        = Rust._pull("shapiro.result$statistic")
                result.exact      = true
                result.alpha      = alpha
                result.hypothesis = Hypothesis.find(options[:hypothesis])
                
                return result
            end
        end
    end
end

module Rust::RBindings
    def wilcox_test(d1, d2, **args)
        paired = args[:paired] || false
        if paired
            return Rust::StatisticalTests::Wilcoxon.paired(d1, d2)
        else
            return Rust::StatisticalTests::Wilcoxon.unpaired(d1, d2)
        end
    end
    
    def t_test(d1, d2, **args)
        paired = args[:paired] || false
        if paired
            return Rust::StatisticalTests::T.paired(d1, d2)
        else
            return Rust::StatisticalTests::T.unpaired(d1, d2)
        end
    end
end
