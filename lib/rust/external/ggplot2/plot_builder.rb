require_relative 'core'

Rust.prerequisite("ggplot2")

module Rust::Plots::GGPlot
    class PlotBuilder
        def self.for_dataframe(data_frame)
            return PlotBuilder.new(data_frame)
        end
        
        def initialize(data=nil)
            @data = data
            
            @aes_options   = {}
            @label_options = {}
            
            @current_context = :title
            
            @layers = []
        end
        
        def with_x(variable, label = nil)
            variable = variable.to_sym if variable.is_a?(String)
            
            @aes_options[:x] = variable
            @current_context = :x
            
            return self
        end
        
        def with_y(variable)
            variable = variable.to_sym if variable.is_a?(String)
            
            @aes_options[:y] = variable
            @current_context = :y
            
            return self
        end
        
        def with_group(variable)
            variable = variable.to_sym if variable.is_a?(String)
            
            @aes_options[:group] = variable
            @current_context = :group
            
            return self
        end
        
        def with_color(variable)
            variable = variable.to_sym if variable.is_a?(String)
            
            @aes_options[:color] = variable
            @current_context = :color
            
            return self
        end
        
        def with_fill(variable)
            variable = variable.to_sym if variable.is_a?(String)
            
            @aes_options[:fill] = variable
            @current_context = :fill
            
            return self
        end
        
        def labeled(value)
            raise "No context for assigning a label" unless @current_context
            @label_options[@current_context] = value
            @current_context = nil
            
            return self
        end
        
        def with_x_label(value)
            @label_options[:x] = value
            
            return self
        end
        
        def with_y_label(value)
            @label_options[:y] = value
            
            return self
        end
        
        def with_color_label(value)
            @label_options[:color] = value
            
            return self
        end
        
        def with_title(value)
            @label_options[:title] = value
            
            return self
        end
        
        def draw_points(**options)
            @layers << GeomPoint.new(**options)
            
            @current_context = nil
            
            return self
        end
        
        def draw_lines(**options)
            @layers << GeomLine.new(**options)
            
            @current_context = nil
            
            return self
        end
        
        def draw_bars(**options)
            @layers << GeomBar.new(**options)
            
            @current_context = nil
            
            return self
        end
        
        def draw_cols(**options)
            @layers << GeomCol.new(**options)
            
            @current_context = nil
            
            return self
        end
        
        def draw_boxplot(**options)
            @layers << GeomBoxplot.new(**options)
            
            @current_context = nil
            
            return self
        end
        
        def draw_histogram(**options)
            @layers << GeomHistogram.new(**options)
            
            @current_context = nil
            
            return self
        end
        
        def draw_density(**options)
            @layers << GeomDensity.new(**options)
            
            @current_context = nil
            
            return self
        end
        
        def with_theme(theme)
            @layers << theme
            
            @current_context = nil
            
            return self
        end
        
        def flip_coordinates
            @layers << FlipCoordinates.new
            
            @current_context = nil
            
            return self
        end
        
        def build
            plot = Plot.new(@data, Aes.new(**@aes_options))
            plot.theme = @theme if @theme
            plot << @layers if @layers.size > 0
            if @label_options.size > 0
                if @label_options.keys.include?(:group)
                    value = @label_options.delete(:group)
                    selected = [:x, :y] - @label_options.keys
                    @label_options[selected.first] = value if selected.size == 1
                end
                
                plot << Labels.new(**@label_options)
            end
            
            return plot
        end
    end
end
