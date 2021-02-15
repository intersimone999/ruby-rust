require_relative 'rust-core'
require_relative 'rust-calls'

module Rust::Plots
    class BasePlot
        def initialize
            @renderables = []
            @options = Rust::Options.new
            @override_options = true
        end
        
        def x_label(label)
            @options['xlab'] = label
            
            return self
        end
        
        def y_label(label)
            @options['ylab'] = label
            
            return self
        end
        
        def palette(size)
            if size <= 1
                return ['black']
            else
                return Rust._pull("hcl.colors(n=#{size})")
            end
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
            
            self._add_renderable(axis)
            
            return self
        end
        
        def grid(grid)
            self._add_renderable(grid)
            
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
        
        def _add_renderable(renderable)
            raise TypeError, "Expected Renderable" unless renderable.is_a?(Renderable)
            @renderables << renderable
            
            return self
        end
        
        def []=(option, value)
            @options[option.to_s] = value
        end
        
        def _do_not_override_options!
            @override_options = false
        end
        
        def show()
            Rust.exclusive do
                self._show
                self._render_others
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
                self._render_others
                Rust._eval("dev.off()")
            end
            
            return self
        end
        
        protected
        def _show()
            raise "You are trying to show a BasePlot"
        end
        
        def _render_others()
            @renderables.each do |renderable|
                renderable._render()
            end
            
            return self
        end
        
        def _augmented_options(options={})
            result = @options.clone
            
            options.each do |key, value|
                result[key] = value if !result[key] || @override_options
            end
            
            result.select! { |k, v| v != nil }
            
            return result
        end
    end
    
    class ScatterPlot < BasePlot
        def initialize(x = nil, y = nil, **options)
            super()
            @series = []
            if x && y
                self.series(x, y, options)
            end
        end
        
        def series(x, y, **options)
            @series << [x, y, options]
            
            return self
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
    
    class BarPlot < BasePlot
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
                function.arguments << Rust::Variable.new("density(plotter.series)")
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
    
    class Renderable
        def initialize
            @options = Rust::Options.new
        end
        
        def []=(option, value)
            @options[option] = value
            
            return self
        end
        
        protected
        def _render()
            raise "You are trying to run an abstract Renderable"
        end
    end
    
    class Axis < Renderable
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
        
        def _render()
            function = Rust::Function.new("axis")
            function.options = @options
            
            function.call
            
            return self
        end
    end
    
    class Grid < Renderable
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
        
        def _render()
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
    def plot(x, y=(1..x.size).to_a, **options)
        result = Rust::Plots::ScatterPlot.new(x, y)
        
        options.each do |k, v|
            result[k] = v
        end
        
        result._do_not_override_options!
        
        result.show
    end
    
    def boxplot(*args, **options)
        result = Rust::Plots::BoxPlot.new
        options.each do |k, v|
            result[k] = v
        end
        
        result._do_not_override_options!
        
        args.each do |s|
            result.series(s)
        end
        
        result.show
    end
end
