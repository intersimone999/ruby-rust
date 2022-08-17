require_relative 'core'

GGPLOT_EXAMPLES = {}

GGPLOT_EXAMPLES[["Quick introduction", /intro/]] = <<-EOS
bind_ggplot! # Avoid using long module names to reach Rust::Plots::GGPlot (simply includes this module)

# Best with a dataframe, but not necessary. If you have it...
df = Rust.toothgrowth
plot = PlotBuilder.for_dataframe(df). # Use a dataframe (symbols will be variable names)
        labeled("Example plot"). # "labeled" sets the label to the last set aesthetic item (x, y, or title, in this case)
        with_x(:len).labeled("X data from df").  # Set all the aesthetics (x, y, ...)
        with_y(:dose).labeled("Y data from df").
        draw_points. # Set the geometries to plot (based on the plot type)
        build # Returns the plot ready to use
plot.show # Show the plot in a window
plot.save("output.pdf", width: 5, height: 4) # Save the plot, width, height etc. are optional

# If you don't have a dataframe...
plot2 = PlotBuilder.new.
        with_x([1,2,3]).labeled("X data from df").
        with_y([3,4,5]).labeled("Y data from df").
        draw_points.
        build
plot2.show
EOS

GGPLOT_EXAMPLES[["Scatter plots", /scatter/]] = <<-EOS
bind_ggplot!
df = Rust.toothgrowth
plot = PlotBuilder.for_dataframe(df).
        with_x(:len).labeled("X data").
        with_y(:dose).labeled("Y data").
        draw_points. # To draw points
        draw_lines.  # To draw lines (keep both to draw both)
        build
plot.show
EOS

GGPLOT_EXAMPLES[["Bar plots", /bar/]] = <<-EOS
bind_ggplot!
df = Rust.toothgrowth
plot = PlotBuilder.for_dataframe(df).
        with_x(:len).labeled("X data").
        with_fill(:supp).labeled("Legend"). # Use with_fill or with_color for stacked plots
        draw_bars. # To draw bars
        build
plot.show
EOS

GGPLOT_EXAMPLES[["Box plots", /box/]] = <<-EOS
bind_ggplot!
df = Rust.toothgrowth
plot = PlotBuilder.for_dataframe(df).
        with_y(:len).labeled("Data to boxplot").
        with_group(:supp).labeled("Groups"). # Groups to plot
        draw_boxplot.
        build
plot.show
EOS

GGPLOT_EXAMPLES[["Histograms", /hist/]] = <<-EOS
bind_ggplot!
df = Rust.toothgrowth
plot = PlotBuilder.for_dataframe(df).
        with_x(:len).labeled("Data to plot").
        with_fill(:supp).labeled("Color"). # Use with_fill or with_color for multiple plots
        draw_histogram.
        build
plot.show
EOS

GGPLOT_EXAMPLES[["Themes", /them/]] = <<-EOS
bind_ggplot!
df = Rust.toothgrowth
# The method with_theme allows to change theme options. The method can be called
# several times, each time the argument does not overwrite the previous options,
# unless they are specified again (in that case, the last specified ones win).
plot = PlotBuilder.for_dataframe(df).
        with_x(:len).labeled("X data").
        with_y(:dose).labeled("Y data").
        draw_points.
        with_theme(
            ThemeBuilder.new('bw').
                title(face: 'bold', size: 12). # Each method sets the property for the related element
                legend do |legend| # Legend and other parts can be set like this
                    legend.position(:left) # Puts the legend on the left
                end.
                axis do |axis| # Modifies the axes
                    axis.line(Theme::BlankElement.new) # Hides the lines for the axes
                    axis.text_x(size: 3) # X axis labels
                end.
                panel do |panel|
                    panel.grid_major(colour: 'grey70', size: 0.2) # Sets the major ticks grid
                    panel.grid_minor(Theme::BlankElement.new) # Hides the minor ticks grid
                end.
                build
        ).build
plot.show
EOS

module Rust::Plots::GGPlot
    def self.help!(topic = nil)
        unless topic
            puts "Topics:"
            GGPLOT_EXAMPLES.keys.each do |key, matcher|
                puts "- #{key}"
            end
            puts "Call again specifying the topic of interest."
        else
            GGPLOT_EXAMPLES.each do |key, value|
                if topic.match(key[1])
                    puts "*** #{key[0]} ***"
                    puts value
                    return
                end
            end
            
            puts "Topic not found"
        end
    end
end
