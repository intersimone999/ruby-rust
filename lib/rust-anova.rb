require_relative 'rust-core'

module Rust
    class ANOVA
        def initialize(data)
            @data = data
        end
        
        def aov(formula, **options)
            mapped = options.map { |k, v| "#{k}=#{v}" }.join(", ")
            mapped = ", " + mapped if mapped.length > 0
            Rust.exclusive do
                Rust._eval("aov.model.result <- aov(#{formula.to_R} #{mapped})")
                return Rust["aov.model.result"]
            end
        end
    end
end

module Rust::RBindings
    def aov(formula, data=nil, **options)
        anova = Rust::ANOVA.new(data)
        return anova.aov(formula, **options)
    end
end
