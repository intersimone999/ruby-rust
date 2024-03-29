require_relative 'core'

module Rust::Plots
    
    ##
    # Allows to create one or many scatter plots.
    
    class ScatterPlot < BasePlot
        
        ##
        # Creates a new scatter plot, given two arrays of values +x+ and +y+ for the respective axes (optional).
        # +options+ can be specified and directly passed to the plot function in R.
        
        def initialize(x = nil, y = nil, **options)
            super()
            @series = []
            if x && y
                self.series(x, y, **options)
            end
        end
        
        ##
        # Adds a new data series, given the values for the +x+ and +y+ axes.
        # +options+ can be specified and directly passed to the plot function in R.
        
        def series(x, y, **options)
            @series << [x, y, options]
            
            return self
        end
        
        ##
        # Sets the thickness of the plot lines.
        
        def thickness(t)
            self['lwd'] = t
            
            return self
        end
        
        ##
        # Changes the plot type to lines.
        
        def lines()
            self['type'] = "l"
            
            return self
        end
        
        ##
        # Changes the plot type to points.
        
        def points()
            self['type'] = "p"
            
            return self
        end
        
        ##
        # Changes the plot type to lines and points.
        
        def lines_and_points()
            self['type'] = "b"
            
            return self
        end
        
        protected
        def _show()
            first = true
            palette = self.palette(@series.size)
            i = 0
            
            base_options = {}
            unless @options['xlim']
                x_values = @series.map { |v| v[0] }.flatten
                y_values = @series.map { |v| v[1] }.flatten
                
                base_options[:xlim] = [x_values.min, x_values.max]
                base_options[:ylim] = [y_values.min, y_values.max]
            end
            
            @series.each do |x, y, options|
                options = options.merge(base_options)
                Rust["plotter.x"] = x
                Rust["plotter.y"] = y
                
                function = nil
                if first
                    function = Rust::Function.new("plot")
                    first = false
                else
                    function = Rust::Function.new("lines")
                end
                
                augmented_options = {}
                augmented_options['col'] = options[:color] || palette[i]
                augmented_options['xlim'] = options[:xlim] if options[:xlim]
                augmented_options['ylim'] = options[:ylim] if options[:ylim]
                
                function.options = self._augmented_options(augmented_options)
                function.arguments << Rust::Variable.new("plotter.x")
                function.arguments << Rust::Variable.new("plotter.y")
                
                function.call
                
                i += 1
            end
            
            return self
        end
    end
    
    ##
    # Represents a bar plot in R.
    
    class BarPlot < BasePlot
        
        ##
        # Creates a new bar plot with the given +bars+ values.
        
        def initialize(bars)
            super()
            @bars = bars
        end
        
        protected
        def _show()
            Rust["plotter.bars"] = @bars.values
            Rust["plotter.labels"] = @bars.keys
            
            Rust._eval("names(plotter.bars) <- plotter.labels")
            
            function = Rust::Function.new("barplot")
            function.options = self._augmented_options
            function.arguments << Rust::Variable.new("plotter.bars")
            
            function.call
            
            return self
        end
    end
end
