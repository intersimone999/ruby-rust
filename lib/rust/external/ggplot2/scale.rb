require_relative 'core'

module Rust::Plots::GGPlot
    class AxisScaler < Layer
        def initialize(axis, type = :continuous, **options)
            @axis = axis
            @type = type
            
            super("scale_#{@axis}_#{@type}", **options)
        end
    end
end
