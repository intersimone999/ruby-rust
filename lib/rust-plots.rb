require_relative 'rust-core'
require_relative 'rust-calls'

module Rust::Plots
    class BasePlot
        def initialize
            @plugins = []
            @options = Rust::Options.new
        end
        
        def x_label(label)
            @options['xlab'] = label
            
            return self
        end
        
        def y_label(label)
            @options['ylab'] = label
            
            return self
        end
        
        def x_range(range)
            @options['xlim'] = range
            
            return self
        end
        
        def y_range(range)
            @options['ylim'] = range
            
            return self
        end
        
        def axis(axis)
            @options['xaxt'] = 'n'
            @options['yaxt'] = 'n'
            
            self.plug(axis)
            
            return self
        end
        
        def title(title)
            @options['main'] = title
            
            return self
        end
        
        def color(color)
            @options['col'] = color
            
            return self
        end
        
        def plug(plugin)
            raise TypeError, "Expected Plugin" unless plugin.is_a?(Plugin)
            @plugins << plugin
            
            return self
        end
        
        def []=(option, value)
            @options[option] = value
        end
        
        def show()
            Rust.exclusive do
                self._show
                self._run_plugins
            end
            
            return self
        end
        
        def pdf(path, **options)
            pdf_function = Rust::Function.new("pdf")
            pdf_function.options = Rust::Options.from_hash(options)
            pdf_function.options['file'] = path
            
            
            Rust.exclusive do
                pdf_function.call
                self._show
                self._run_plugins
                Rust._eval("dev.off()")
            end
            
            return self
        end
        
        protected
        def _show()
            raise "You are trying to show a BasePlot"
        end
        
        def _run_plugins()
            @plugins.each do |plugin|
                plugin._run()
            end
            
            return self
        end
        
        def _augmented_options(options={})
            result = @options.clone
            
            options.each do |key, value|
                result[key] = value
            end
            
            result.select! { |k, v| v != nil }
            
            return result
        end
    end
    
    class ScatterPlot < BasePlot
        def initialize(x, y)
            super()
            @x = x
            @y = y
        end
        
        def thickness(t)
            self['lwd'] = t
            
            return self
        end
        
        def lines()
            self['type'] = "l"
            
            return self
        end
        
        def points()
            self['type'] = "p"
            
            return self
        end
        
        def lines_and_points()
            self['type'] = "b"
            
            return self
        end
        
        protected
        def _show()
            Rust["plotter.x"] = @x
            Rust["plotter.y"] = @y
            
            function = Rust::Function.new("plot")
            function.options = self._augmented_options
            function.arguments << Rust::Variable.new("plotter.x")
            function.arguments << Rust::Variable.new("plotter.y")
            
            function.call
            
            return self
        end
    end
    
    class DistributionPlot < BasePlot
        def initialize
            super()
            @series = []
        end
        
        def series(data, **options)
            @series << [data, options]
            
            return self
        end
    end
    
    class DensityPlot < DistributionPlot
        protected
        def _show()
            first = true
            @series.each do |data, options|
                Rust["plotter.series"] = data
                
                if first
                    first = false
                    command = "plot"
                else
                    command = "lines"
                end
                
                function = Rust::Function.new(command)
                function.options = self._augmented_options({"col" => options[:color]})
                function.arguments << Rust::Variable.new("plotter.series")
                function.call
            end
            
            return self
        end
    end
    
    class BoxPlot < DistributionPlot
        protected
        def _show()
            function = Rust::Function.new("boxplot")
            
            names = []
            @series.each_with_index do |data, i|
                series, options = *data
                varname = "plotter.series#{i}"
                Rust[varname] = series
                function.arguments << Rust::Variable.new(varname)
                names << (options[:name] || (i+1).to_s)
            end
            
            function.options = self._augmented_options({'names' => names})
            
            function.call
            
            return self
        end
    end
    
    class Plugin
        def initialize
            @options = Rust::Options.new
        end
        
        def []=(option, value)
            @options[option] = value
            
            return self
        end
        
        protected
        def _run()
            raise "You are trying to run an abstract Plugin"
        end
    end
    
    class Axis < Plugin
        BELOW = 1
        LEFT  = 2
        ABOVE = 3
        RIGHT = 4
        
        def initialize(side)
            super()
            
            self['side'] = side
            self.at(nil)
            self.labels(true)
        end
        
        def at(values)
            self['at'] = values
            
            return self
        end
        
        def vertical_labels
            self['las'] = 2
            
            return self
        end
        
        def horizontal_labels
            self['las'] = 1
            
            return self
        end
        
        def labels(value)
            self['labels'] = value
            
            return self
        end
        
        def _run()
            function = Rust::Function.new("axis")
            function.options = @options
            
            function.call
            
            return self
        end
    end
    
    class Grid < Plugin
        def initialize
            super()
            
            @x = Float::NAN
            @y = Float::NAN
        end
        
        def x(value)
            @x = value
            
            return self
        end
        
        def y(value)
            @y = value
            
            return self
        end
        
        def auto_x
            @x = nil
            
            return self
        end
        
        def auto_y
            @y = nil
            
            return self
        end
        
        def hide_x
            @x = Float::NAN
            
            return self
        end
        
        def hide_y
            @y = Float::NAN
            
            return self
        end
        
        def _run()
            function = Rust::Function.new("grid")
            
            function.arguments << @x
            function.arguments << @y
            function.options = @options
            
            function.call
            
            return self
        end
    end
end

module Rust::RBindings
    def plot(x, y)
        Rust::Plots::ScatterPlot.new(x, y).show
    end
end
