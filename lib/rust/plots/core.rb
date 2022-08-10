require_relative '../core'

##
# Module that contains classes for plotting.

module Rust::Plots
    
    ##
    # Represents a generic plot in R.
    
    class BasePlot
        
        ##
        # Creates a new base plot object.
        
        def initialize
            @renderables = []
            @options = Rust::Options.new
            @override_options = true
        end
        
        ##
        # Sets the x-axis label.
        
        def x_label(label)
            @options['xlab'] = label
            
            return self
        end
        
        ##
        # Sets the y-axis label.
        
        def y_label(label)
            @options['ylab'] = label
            
            return self
        end
        
        ##
        # Returns a color palette of the given +size+.
        
        def palette(size)
            if size <= 1
                return ['black']
            else
                return Rust._pull("hcl.colors(n=#{size})")
            end
        end
        
        ##
        # Sets the limits for the x-axis.
        
        def x_range(range)
            @options['xlim'] = range
            
            return self
        end
        alias :xlim :x_range
        
        ##
        # Sets the limits for the y-axis.
        
        def y_range(range)
            @options['ylim'] = range
            
            return self
        end
        alias :ylim :y_range
        
        ##
        # Adds an +axis+ to show instead of the default ones.
        
        def axis(axis)
            @options['xaxt'] = 'n'
            @options['yaxt'] = 'n'
            
            self._add_renderable(axis)
            
            return self
        end
        
        ##
        # Shows the given +grid+.
        
        def grid(grid)
            self._add_renderable(grid)
            
            return self
        end
        
        ##
        # Sets the +title+ of the plot.
        
        def title(title)
            @options['main'] = title
            
            return self
        end
        
        ##
        # Sets the +color+ of the plot.
        
        def color(color)
            @options['col'] = color
            
            return self
        end
        
        def _add_renderable(renderable)
            raise TypeError, "Expected Renderable" unless renderable.is_a?(Renderable)
            @renderables << renderable
            
            return self
        end
        
        ##
        # Sets any R +option+ with the given +value+.
        
        def []=(option, value)
            @options[option.to_s] = value
        end
        
        def _do_not_override_options!
            @override_options = false
        end
        
        ##
        # Shows the plot in a window.
        
        def show()
            Rust.exclusive do
                self._show
                self._render_others
            end
            
            return self
        end
        
        ##
        # Prints the plot on a PDF file at path. +options+ can be specified for the PDF (e.g., width and height).
        
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
    
    ##
    # Represents any element that can be rendered in a plot (e.g., axes or grids).
    
    class Renderable
        
        ##
        # Creates a new empty renderable object.
        
        def initialize
            @options = Rust::Options.new
        end
        
        ##
        # Sets an option for the renderable object.
        
        def []=(option, value)
            @options[option] = value
            
            return self
        end
        
        protected
        def _render()
            raise "You are trying to run an abstract Renderable"
        end
    end
    
    ##
    # Represents an axis for a plot.
    
    class Axis < Renderable
        BELOW = 1
        LEFT  = 2
        ABOVE = 3
        RIGHT = 4
        
        ##
        # Creates a new axis at the given +side+ (constants BELOW, LEFT, ABOVE, and RIGHT are available).
        
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
    
    ##
    # Represents a grid for a plot.
    
    class Grid < Renderable
        
        ##
        # Creates a new grid
        
        def initialize
            super()
            
            @x = Float::NAN
            @y = Float::NAN
        end
        
        ##
        # Sets the x intervals.
        
        def x(value)
            @x = value
            
            return self
        end
        
        ##
        # Sets the y intervals.
        
        def y(value)
            @y = value
            
            return self
        end
        
        ##
        # Automatically sets the x intervals.
        
        def auto_x
            @x = nil
            
            return self
        end
        
        ##
        # Automatically sets the y intervals.
        
        def auto_y
            @y = nil
            
            return self
        end
        
        ##
        # Hides x axis lines.
        
        def hide_x
            @x = Float::NAN
            
            return self
        end
        
        ##
        # Hides y axis lines.
        
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
