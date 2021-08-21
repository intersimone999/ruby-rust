require_relative '../core'

Rust.prerequisite('effsize')

module Rust::EffectSize
    class Result
        attr_accessor   :name
        attr_accessor   :estimate
        attr_accessor   :confidence_interval
        attr_accessor   :confidence_level
        attr_accessor   :magnitude
        
        def to_s
            return "#{name} = #{estimate} (#{magnitude}) [#{confidence_interval.min}, #{confidence_interval.max}]"
        end
    end

    class CliffDelta
        def self.compute(d1, d2)
            raise TypeError, "Expecting Array of numerics" if !d1.is_a?(Array) || !d1.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !d2.is_a?(Array) || !d2.all? { |e| e.is_a?(Numeric) }
            
            if d1.size <= 1 || d2.size <= 1
                return Rust::EffectSize::Result.new
            end
            
            Rust.exclusive do
                Rust['effsize.a'] = d1
                Rust['effsize.b'] = d2
                
                Rust._eval("effsize.result = cliff.delta(effsize.a, effsize.b)")
                
                result = Rust::EffectSize::Result.new
                result.name                 = "Cliff's delta"
                result.estimate             = Rust._pull("effsize.result$estimate")                         rescue Float::NAN
                result.confidence_interval  = Range.new(*Rust._pull("effsize.result$conf.int"))             rescue nil
                result.confidence_level     = Rust._pull("effsize.result$conf.level")                       rescue Float::NAN
                result.magnitude            = Rust._pull("as.character(effsize.result$magnitude)").to_sym   rescue nil
                
                return result
            end
        end
    end
    
    class CohenD
        def self.compute(d1, d2)
            raise TypeError, "Expecting Array of numerics" if !d1.is_a?(Array) || !d1.all? { |e| e.is_a?(Numeric) }
            raise TypeError, "Expecting Array of numerics" if !d2.is_a?(Array) || !d2.all? { |e| e.is_a?(Numeric) }
            
            if d1.size <= 1 || d2.size <= 1
                return Rust::EffectSize::Result.new
            end
            
            Rust.exclusive do
                Rust['effsize.a'] = d1
                Rust['effsize.b'] = d2
                
                Rust._eval("effsize.result = cohen.d(effsize.a, effsize.b)")
                
                result = Rust::EffectSize::Result.new
                result.name                 = "Cohen's d"
                result.estimate             = Rust._pull("effsize.result$estimate")                       rescue Float::NAN
                result.confidence_interval  = Range.new(*Rust._pull("effsize.result$conf.int"))           rescue nil
                result.confidence_level     = Rust._pull("effsize.result$conf.level")                     rescue Float::NAN
                result.magnitude            = Rust._pull("as.character(effsize.result$magnitude)").to_sym rescue nil
                
                return result
            end
        end
    end
end

module Rust::RBindings
    def cliff_delta(d1, d2)
        Rust::EffectSize::CliffDelta.compute(d1, d2)
    end
    
    def cohen_d(d1, d2, **args)
        Rust::EffectSize::CohenD.compute(d1, d2)
    end
end
