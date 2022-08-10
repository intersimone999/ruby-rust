require_relative 'core'

module Rust::Plots
    
    ##
    # Represents any distribution-related plot (e.g., boxplots).
    
    class DistributionPlot < BasePlot
        def initialize
            super()
            @series = []
        end
        
        ##
        # Adds a series of data points. +options+ can be specified and directly passed to the R plotting function.
        
        def series(data, **options)
            @series << [data, options]
            
            return self
        end
    end
    
    ##
    # Represents a density plot in R.
    
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
    
    ##
    # Represents a boxplot in R.
    
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
end
