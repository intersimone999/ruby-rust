require_relative 'core'

module Rust::Plots::GGPlot
    class Geom < Layer
        def initialize(type, arguments = [], **options)
            super("geom_#{type}", **options)
            @type = type
            @arguments = Rust::Arguments.new(arguments)
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
    
    class GeomHistogram < Geom
        def initialize(arguments = [], **options)
            super("histogram", arguments, **options)
        end
    end
    
    class GeomDensity < Geom
        def initialize(arguments = [], **options)
            super("density", arguments, **options)
        end
    end
end

module Rust::RBindings
    def geom_point(*arguments, **options)
        return Rust::Plots::GGPlot::GeomPoint.new(*arguments, **options)
    end
    
    def geom_line(*arguments, **options)
        return Rust::Plots::GGPlot::GeomLine.new(*arguments, **options)
    end
    
    def geom_col(*arguments, **options)
        return Rust::Plots::GGPlot::GeomCol.new(*arguments, **options)
    end
    
    def geom_bar(*arguments, **options)
        return Rust::Plots::GGPlot::GeomBar.new(*arguments, **options)
    end
    
    def geom_boxplot(*arguments, **options)
        return Rust::Plots::GGPlot::GeomBoxplot.new(*arguments, **options)
    end
    
    def geom_histogram(*arguments, **options)
        return Rust::Plots::GGPlot::GeomHistogram.new(*arguments, **options)
    end
    
    def geom_density(*arguments, **options)
        return Rust::Plots::GGPlot::GeomDensity.new(*arguments, **options)
    end
end
