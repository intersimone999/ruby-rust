require_relative 'core'

module Rust::Plots::GGPlot
    class Geom < Layer
        def initialize(type, arguments = [], **options)
            super()
            @type = type
            
            @arguments = Rust::Arguments.new(arguments)
            @options = Rust::Options.from_hash(options)
        end
        
        def to_R
            function = Rust::Function.new("geom_#@type")
            function.arguments = @arguments if @arguments
            function.options = @options if @options
            return function.to_R
        end
    end
    
    class GeomPoint < Geom
        def initialize(arguments = [], **options)
            super("point", arguments, **options)
        end
    end
    
    class GeomLine < Geom
        def initialize(arguments = [], **options)
            super("line", arguments, **options)
        end
    end
    
    class GeomCol < Geom
        def initialize(arguments = [], **options)
            super("col", arguments, **options)
        end
    end
    
    class GeomBoxplot < Geom
        def initialize(arguments = [], **options)
            super("boxplot", arguments, **options)
        end
    end
    
    class GeomBar < Geom
        def initialize(arguments = [], **options)
            super("bar", arguments, **options)
        end
    end
end

module Rust::RBindings
    def geom_point(*arguments, **options)
        return Rust::Plots::GGPlot::Geom.new("point", *arguments, **options)
    end
    
    def geom_line(*arguments, **options)
        return Rust::Plots::GGPlot::Geom.new("line", *arguments, **options)
    end
    
    def geom_col(*arguments, **options)
        return Rust::Plots::GGPlot::Geom.new("col", *arguments, **options)
    end
    
    def geom_boxplot(*arguments, **options)
        return Rust::Plots::GGPlot::Geom.new("boxplot", *arguments, **options)
    end
end
