require 'rust'

Rust.prerequisite('robustbase')

module Rust::Plots
    class AdjustedBoxplot < DistributionPlot
        protected
        def _show()
            function = Rust::Function.new("adjbox")
            
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

module Rust::RBindings
    def adjbox(*args, **options)
        result = Rust::Plots::AdjustedBoxplot.new
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
