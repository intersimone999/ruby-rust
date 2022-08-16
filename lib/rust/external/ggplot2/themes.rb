require 'json'
require_relative 'core'

module Rust::Plots::GGPlot
    class Theme < Layer
        def self.from_h(options)            
            starting = options.delete('_starting')
            options = options.map do |key, value|
                if value.is_a?(Hash)
                    case value.delete('_type').split("::").last
                    when 'TextElement'
                        [key, TextElement.new(**value)]
                    when 'RectElement'
                        [key, RectElement.new(**value)]
                    when 'TextElement'
                        [key, TextElement.new(**value)]
                    when 'LineElement'
                        [key, LineElement.new(**value)]
                    end
                else
                    [key, value]
                end
            end.to_h
            
            return Theme.new(starting, **options)
        end
        
        def self.load(filename)
            json = JSON.parse(File.read(filename))
            return self.from_h(json.to_h)
        end
        
        def initialize(starting, **options)
            if starting
                @starting = "theme_" + starting
            end
            @options = options
        end
        
        def option(key, value)
            @options[key] = value
        end
        
        def to_R
            options = @options.map { |k, v| [k.to_s.gsub("_", "."), v] }.to_h
            
            function = Rust::Function.new("theme")
            function.options = Rust::Options.from_hash(options)
            
            result = function.to_R
            result = Rust::Function.new(@starting).to_R + " + " +  result if @starting
            
            return result
        end
        
        def to_h
            options = @options.clone
            
            options['_starting'] = @starting.sub("theme_", "")
            options = options.map do |key, value|
                [key, value.is_a?(Theme::Element) ? value.to_h : value]
            end.to_h
            
            return options
        end
        
        def save(path, force = false)
            if !force && FileTest.exist?(path)
                raise "File already existing."
            end
            
            File.open(path, "w") do |f|
                f.write(
                    JSON.pretty_generate(
                        self.to_h
                    )
                )
            end
            
            return true
        end
    end
    
    class Theme::Element
        attr_reader :options
        
        def initialize(**options)
            @options = options
        end
        
        def r_function
            raise "Not implemented for generic theme element"
        end
        
        def to_R
            options = @options.map { |k, v| [k.to_s.gsub("_", "."), v] }.to_h
            
            function = Rust::Function.new(self.r_function)
            function.options = Rust::Options.from_hash(options)
            
            return function.to_R
        end
        
        def to_h
            hash = @options.clone
            hash['_type'] = self.class.name
            return hash
        end
    end
    
    class Theme::TextElement < Theme::Element
        def r_function
            return "element_text"
        end
    end
    
    class Theme::LineElement < Theme::Element
        def r_function
            return "element_line"
        end
    end
    
    class Theme::RectElement < Theme::Element
        def r_function
            return "element_rect"
        end
    end
    
    class Theme::BlankElement < Theme::Element
        def r_function
            return "element_blank"
        end
    end
    
    class ThemeComponentBuilder
        def initialize(namespace=nil)
            @namespace = namespace
            @options = {}
        end
        
        def option(key, value)
            key = "#@namespace.#{key}" if @namespace
            @options[key] = value
            
            return self
        end
        
        def [](key)
            key = "#@namespace.#{key}" if @namespace
            return @options[key]
        end
        
        def line_el(value)
            if value.is_a?(Theme::LineElement) || value.is_a?(Theme::BlankElement)
                return value
            elsif value.is_a?(Hash)
                return Theme::LineElement.new(**value)
            else
                raise "Expected line or hash"
            end
        end
        
        def rect_el(value)
            if value.is_a?(Theme::RectElement) || value.is_a?(Theme::BlankElement)
                return value
            elsif value.is_a?(Hash)
                return Theme::RectElement.new(**value)
            else
                raise "Expected rect or hash"
            end
        end
        
        def text_el(value)
            if value.is_a?(Theme::TextElement) || value.is_a?(Theme::BlankElement)
                return value
            elsif value.is_a?(Hash)
                return Theme::TextElement.new(**value)
            else
                raise "Expected text or hash"
            end
        end
        
        def unit_el(value)
            numeric = nil
            unit = nil
            
            if input.is_a?(String)
                numeric, unit = *input.scan(/^([0-9.]+)([A-Za-z]+)/).flatten
                
                raise "Unclear numeric part in #{input}" unless numeric
                raise "Unclear unit part in #{input}"    unless unit
            elsif input.is_a?(Numeric)
                numeric = input
                unit = "npc"
            end
            
            raise "Unable to handle #{input}" unless numeric && unit
            
            function = Rust::Function.new("units")
            function.arguments = Rust::Arguments.new([numeric, unit])
            
            return function.to_R
        end
        
        def alignment_el(value)
            if value.is_a?(String) || value.is_a?(Symbol)
                case value.to_s.downcase
                when 'left'
                    value = 1
                when 'right'
                    value = 0
                else
                    value = 1
                end
            end
            
            return value
        end
        
        def numeric_el(value)
            raise "Expected number" unless value.is_a?(Numeric)
            return value
        end
        
        def build
            @options
        end
    end
    
    class ThemeBuilder < ThemeComponentBuilder
        def initialize(starting = 'bw')
            super("plot")
            @starting = starting
        end
        
        def background(value)
            self.option('background', rect_el(value))
        end
        
        def title(value)
            self.option('title', text_el(value))
        end
        
        def axis
            builder = ThemeAxisBuilder.new
            yield builder
            
            @options.merge!(builder.build)
            return self
        end
        
        def legend
            builder = ThemeLegendBuilder.new
            yield builder
            
            @options.merge!(builder.build)
            return self
        end
        
        def panel
            builder = ThemePanelBuilder.new
            yield builder
            
            @options.merge!(builder.build)
            return self
        end
        
        def build
            return Theme.new(@starting, **@options)
        end
    end
    
    class ThemeAxisBuilder < ThemeComponentBuilder
        def initialize
            super("axis")
        end
        
        def line(value)
            self.option('line', line_el(value))
        end
        
        def text(value)
            self.option('text', text_el(value))
        end
        
        def text_x(value)
            self.option('text.x', text_el(value))
        end
        
        def text_y(value)
            self.option('text.y', text_el(value))
        end
        
        def title(value)
            self.option('title', text_el(value))
        end
        
        def title_x(value)
            self.option('title.x', text_el(value))
        end
        
        def title_y(value)
            self.option('title.y', text_el(value))
        end
        
        def ticks(value)
            self.option('ticks', line_el(value))
        end
        
        def ticks_length(value)
            self.option('ticks.length', unit_el(value))
        end
    end
    
    class ThemeLegendBuilder < ThemeComponentBuilder
        def initialize
            super("legend")
        end
        
        def position(value)
            self.option('position', value)
        end
        
        def justification(value)
            self.option('justification', value)
        end
        
        def background(value)
            self.option('background', rect_el(value))
        end
        
        def key_background(value)
            self.option('key', rect_el(value))
        end
        
        def key_size(value)
            self.option('key.size', unit_el(value))
        end
        
        def key_height(value)
            self.option('key.height', unit_el(value))
        end
        
        def key_width(value)
            self.option('key.width', unit_el(value))
        end
        
        def margin(value)
            self.option('margin', unit_el(value))
        end
        
        def text(value)
            self.option('text', text_el(value))
        end
        
        def text_align(value)
            self.option('text.align', alignment_el(value))
        end
        
        def title(value)
            self.option('title', text_el(value))
        end
        
        def title_align(value)
            self.option('key.size', alignment_el(value))
        end
    end
    
    class ThemePanelBuilder < ThemeComponentBuilder
        def initialize
            super("panel")
        end
        
        def background(value)
            self.option('background', rect_el(value))
        end
        
        def border(value)
            self.option('border', rect_el(value))
        end
        
        def grid_major(value)
            self.option('grid.major', line_el(value))
        end
        
        def grid_major_x(value)
            self.option('grid.major.x', line_el(value))
        end
        
        def grid_major_y(value)
            self.option('grid.major.y', line_el(value))
        end
        
        def grid_minor(value)
            self.option('grid.minor', line_el(value))
        end
        
        def grid_minor_x(value)
            self.option('grid.minor.x', line_el(value))
        end
        
        def grid_minor_y(value)
            self.option('grid.minor.y', line_el(value))
        end
        
        def aspect_ratio(value)
            self.option('aspect.ratio', numeric_el(value))
        end
        
        def margin(value)
            self.option('margin', unit_el(value))
        end
        
        def margin_x(value)
            self.option('margin.x', unit_el(value))
        end
        
        def margin_y(value)
            self.option('margin.y', unit_el(value))
        end
    end
    
    self.default_theme = ThemeBuilder.new\
            .title(face: 'bold', size: 12)\
            .legend do |legend|
                legend.background(fill: 'white', size: 4, colour: 'white')
                legend.position([0, 1])
                legend.justification([0, 1])
            end.axis do |axis| 
                axis.ticks(colour: 'grey70', size: 0.2)
            end.panel do |panel|
                panel.grid_major(colour: 'grey70', size: 0.2)
                panel.grid_minor(Theme::BlankElement.new)
            end.build
end
