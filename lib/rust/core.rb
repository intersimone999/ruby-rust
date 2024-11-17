require_relative 'core/rust'
require_relative 'core/csv'
require_relative 'core/manual'

self_path = File.expand_path(__FILE__)
Dir.glob(File.join(File.dirname(self_path), "core/types/*.rb")).each do |lib|
    require_relative lib
end

Rust::Manual.register(:base, "Quick intro", "Core philosophy behind Rust.")
Rust::Manual.for(:base).register('Introduction', /intro/,
<<-EOS
Rust is a statistical library. Rust wraps R and its libraries to achieve this goal.
Rust aims at:
- Making easier for Ruby developers make all the kinds of operations that are straightforward in R;
- Providing an object-oriented interface, more familiar than the one in R.

Rust can be used in two ways:
- By using the object-oriented interface (advised if you are writing a script);
- By using the R bindings, that allow to use Ruby pretty much like R (handful if you are using it from IRB).

Rust provides wrappers for many elements, including types (e.g., data frames), statistical hypothesis tests, plots, and so on.
Under the hood, Rust creates an R environment (through rinruby), through which Rust can perform the most advanced operations,
for which a re-implementation would be impractical.
EOS
)

Rust::Manual.for(:base).register('Types', /type/,
<<-EOS
Rust provides wrappers for the most commonly-found types in R. Specifically, the following types are available:
- Data frames → Rust::DataFrame
- Factors → Rust::Factor
- Matrices → Rust::Matrix
- Lists → Rust::List
- S4 classes → Rust::S4Class
- Formulas → Rust::Formula

Note that some of them (e.g., data frames and matrices) are not just wrappers, but complete re-implementations of the R
types (for performance reasons).
EOS
)

Rust::Manual.for(:base).register('CSVs', /csv/,
<<-EOS
Rust allows to read and write CSV files, mostly like in R.
To read a CSV file, you can use:
Rust::CSV.read(filename)

It returns a data frame. You can also specify the option "headers" to tell if the first row in the CSV contains the headers 
(column names for the data frame). Other options get directly passed to the R function "read.csv".

To write a CSV file, you can use:
Rust::CSV.write(filename, data_frame)

It writes the given data frame on the file at filename.
EOS
)
