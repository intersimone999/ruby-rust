require_relative '../../../rust'

Rust.prerequisite("ggplot2")

module Rust::Plots::GGPlot
    def self.default_theme
        @@theme
    end
    
    def self.default_theme=(theme)
        @@theme = theme.freeze
    end
    
    class Layer
    end
    
    class Aes
        def initialize(**options)
            options = options.map { |k, v| [k, Rust::Variable.new(v)] }.to_h
            @options = Rust::Options.from_hash(options)
        end
        
        def to_R
            function = Rust::Function.new("aes")
            function.options = @options if @options
            return function.to_R
        end
    end
    
    class Plot
        attr_accessor   :theme
        attr_accessor   :aes
        
        def initialize(data, aes = nil)
            @layers = []
            
            @data = data
            @aes = aes
            @theme = Rust::Plots::GGPlot.default_theme
        end
        
        def layer(layer)
            @layers << layer
        end
        
        def show()
            Rust.exclusive do
                dataset_name = nil
                if @data
                    dataset_name = "ggplotter.data"
                    @data.load_in_r_as(dataset_name)
                end
                r = self.to_R(dataset_name)
                Rust._eval(r)
            end
        end
        
        def to_R(data_set_name="ggplotter.data")
            function = Rust::Function.new("ggplot")
            function.arguments = Rust::Arguments.new
            function.arguments << (data_set_name ? Rust::Variable.new(data_set_name) : nil)
            function.arguments << @aes if @aes
            
            result = function.to_R
            result += " + " + @theme.to_R
            @layers.each do |layer|
                result += " + " + layer.to_R
            end
            
            return result
        end
        
        def <<(others)
            if others.is_a?(Array) && others.all? { |o| o.is_a?(Layer) }
                @layers += others + others.map { |o| o.layers }.flatten
            elsif others.is_a?(Layer)
                @layers << others
            else
                raise ArgumentError, "Expected Layer or Array or Layers"
            end
            
            return self
        end
        
        def +(others)
            copy = self.deep_clone
            copy << others
            return copy
        end
        
        def inspect(show = true)
            self.show if show
            return super()
        end
    end
    
    class Labels < Layer
        def initialize(**options)
            super()
            @options = Rust::Options.from_hash(options)
        end
        
        def to_R
            function = Rust::Function.new("labs")
            function.arguments = @arguments if @arguments
            function.options = @options if @options
            return function.to_R
        end
    end
end

module Rust::RBindings
    def ggplot(*arguments)
        Rust::Plots::GGPlot::Plot.new(*arguments)
    end
    
    def aes(**options)
        Rust::Plots::GGPlot::Aes.new(**options)
    end
    
    def labs(**options)
        Rust::Plots::GGPlot::Labels.new(**options)
    end
    alias :labels :labs
end
