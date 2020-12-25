# Rust
[![Gem Version](https://badge.fury.io/rb/rust.svg)](https://badge.fury.io/rb/rust)

Rust provides Ruby Statistic facilities. It mostly relies on R (rinruby gem) and it provides the most useful statistical functions in a Ruby wrapper.

## Install
To install the latest version of Rust, simply run the following command

```
gem install rust
```

## Structure
Everything in Rust is defined in the `Rust` module and organized in submodules, one for each core feature. The modules currently available are:

- `Rust` contains the core data structures (data frames, matrices) and functions that allow to interact with R. The data structures provide their core functions (e.g., data frames have the `merge` method);
- `Rust::Descriptive` provides descriptive statistic functions (e.g., mean, variance);
- `Rust::Correlation` provides object to compute correlations (Pearson, Spearman, and Kendall);
- `Rust::StatisticalTest` allows to run statistical hypothesis tests (t-test, Wilcoxon);
- `Rust::EffectSize` allows to compute the effect size (Cohen d, Cliff's delta);
- `Rust::CSV` allows to read and write CSV files;
- `Rust::Plots` provides basic plotting features.

Each module can optionally define some R binding methods: such methods allow to provide an interface very similar to R. To use these bindings, just call the method `bind_r!`.

## Examples
Here we provide some examples to quick-start using Rust.

### CSVs and data frames

```ruby
# Load a data frame with columns id, name, surname, height
people = Rust::CSV.read("people.csv", headers: true)
# Sum the values of the column "test" of dataframe
p people.column("height").sum

# Load a data frame with columns id, amount
purchases = Rust::CSV.read("purchases.csv", headers: true)
# Merge the two dataframes in one with columns id, name, surname, height, purchase.amount
merged = people.merge(purchases, ["id"], "", "purchase")
# Gets the surnames of the the people who spent more than 100
p merged.select_rows { |r| r['purchase.amount'] > 100 }.column("surname") 

```

### Plots
```ruby
# Create a scatter plot object (does not show anything) with the x and y values
sp = Rust::Plots::ScatterPlot.new([1,2,3,4,5], [2,3,4,5,6])
# Will connect the points with the lines
sp.lines
# Show the plot
sp.show

# Create a box plot object (does not show anything)
bp = Rust::Plots::BoxPlot.new
# Add two series of data, one named 'hello', one named 'world'
bp.series([1,2,3,5,4,6], name: 'hello')
bp.series([2,4,6,3,5,4], name: 'world')
# Save the plot on the PDF file "result.pdf" with a with of 6 inches
bp.pdf("result.pdf", width: 6)
```

