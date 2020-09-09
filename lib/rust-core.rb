require 'code-assertions'
require 'stringio'
require 'rinruby'
require 'csv'

module Rust
    CLIENT_MUTEX = Mutex.new
    R_MUTEX      = Mutex.new
    
    R_ENGINE     = RinRuby.new(echo: false)
    
    @@debugging = false
    @@in_client_mutex = false
    
    def self.debug
        @@debugging = true
    end
    
    def self.exclusive
        result = nil
        CLIENT_MUTEX.synchronize do
            @@in_client_mutex = true
            result = yield
            @@in_client_mutex = false
        end
        return result
    end
    
    def self.[]=(variable, value)
        if value.is_a?(RustDatatype)
            value.load_in_r_as(variable.to_s)
        elsif value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(Array)
            R_ENGINE.assign(variable, value)
        else
            raise "Given #{value.class}, expected RustDatatype, String, Numeric, or Array"
        end
        
    end
    
    def self.[](variable, type=RustDatatype)
        return type.pull_variable(variable)
    end
    
    def self._eval_big(r_command, return_warnings = false)
        r_command = r_command.join("\n") if r_command.is_a?(Array)
        
        self._rexec(r_command, return_warnings) do |cmd|
            result = true
            instructions = cmd.lines
            
            while instructions.size > 0
                current_command = ""
                
                while (instructions.size > 0) && (current_command.length + instructions.first.length < 10000)
                    current_command << instructions.shift
                end
                
                result &= R_ENGINE.eval(current_command)
            end
            
            result
        end
    end
    
    def self._pull(r_command, return_warnings = false)
        self._rexec(r_command, return_warnings) { |cmd| R_ENGINE.pull(cmd) }
    end
    
    def self._eval(r_command, return_warnings = false)
        self._rexec(r_command, return_warnings) { |cmd| R_ENGINE.eval(cmd) }
    end
    
    def self._rexec(r_command, return_warnings = false)
        puts "Calling _rexec with command: #{r_command}" if @@debugging
        R_MUTEX.synchronize do
            assert("This command must be executed in an exclusive block") { @@in_client_mutex }
            
            result = nil
            begin
                $stdout = StringIO.new
                if return_warnings
                    R_ENGINE.echo(true, true)
                else
                    R_ENGINE.echo(false, false)
                end
                result = yield(r_command)
            ensure
                R_ENGINE.echo(false, false)
                warnings = $stdout.string
                $stdout = STDOUT
            end
            
            if return_warnings
                return result, warnings.lines.map { |w| w.strip.chomp }
            else
                return result
            end
        end
    end
    
    class RustDatatype
        def self.pull_variable(variable)
            return Rust._pull(variable)
        end
        
        def load_in_r_as(r_instance, variable_name)
            raise "Not implemented"
        end
    end
    
    class DataFrame < RustDatatype
        def self.pull_variable(variable)
            hash = {}
            colnames = Rust._pull("colnames(#{variable})")
            colnames.each do |col|
                hash[col] = Rust._pull("#{variable}$#{col}")
            end
            return DataFrame.new(hash)
        end
        
        def initialize(labels_or_data)
            @data = {}
            
            if labels_or_data.is_a? Array
                @labels = labels_or_data.map { |l| l.to_s }
                @labels.each { |label| @data[label] = [] }
            elsif labels_or_data.is_a? Hash
                @labels = labels_or_data.keys.map { |l| l.to_s }
                @data = labels_or_data.clone
            end
        end
        
        def row(i)
            if i < 0 || i >= self.rows
                return nil
            else
                return @data.map { |label, values| [label, values[i]] }.to_h
            end
        end
        
        def shuffle(*args)
            result = DataFrame.new(@labels)
            
            buffer = []
            self.each do |row|
                buffer << row
            end
            buffer.shuffle!(*args).each do |row|
                result << row
            end
            
            return result
        end
        
        def [](rows, cols=nil)
            raise "You must specify either rows or columns to select" if !rows && !cols
            result = self
            if rows && (rows.is_a?(Range) || rows.is_a?(Array))
                result = result.select_rows { |row, i| rows.include?(i) }
            end
            
            if cols && cols.is_a?(Array)
                cols = cols.map { |c| c.to_s }
                result = result.select_columns(cols)
            end
            
            return result
        end
        
        def column(name)
            return @data[name]
        end
        
        def rename_column!(old_name, new_name)
            raise "This DataFrame does not contain a column named #{old_name}" unless @labels.include?(old_name)
            raise "This DataFrame already contains a column named #{new_name}" if @labels.include?(new_name)
            
            @data[new_name.to_s] = @data.delete(old_name)
            @labels[@labels.index(old_name)] = new_name
        end
        
        def transform_column!(column)
            @data[column].map! { |e| yield e }
        end
        
        def select_rows
            result = DataFrame.new(self.column_names)
            self.each_with_index do |row, i|
                result << row if yield row, i
            end
            return result
        end
        
        def select_columns(cols=nil)
            raise "You must specify either the columns you want to select or a selection block" if !cols && !block_given?
            
            result = self.clone
            @labels.each do |label|
                if cols
                    result.delete_column(label) unless cols.include?(label)
                else
                    result.delete_column(label) unless yield label
                end
            end
            return result
        end
        alias :select_cols :select_columns
        
        def delete_column(column)
            @labels.delete(column)
            @data.delete(column)
        end
        
        def column_names
            return @labels.map { |k| k.to_s }
        end
        alias :colnames :column_names
        
        def rows
            @data.values[0].size
        end
        
        def columns
            @labels.size
        end
        
        def add_row(row)
            if row.is_a?(Array)
                raise "Expected an array of size #{@data.size}" unless row.size == @data.size
                
                @labels.each_with_index do |label, i|
                    @data[label] << row[i]
                end
                
                return true
            elsif row.is_a?(Hash)
                raise "Expected a hash with the following keys: #{@data.keys}" unless row.keys.map { |l| l.to_s }.sort == @data.keys.sort
                
                row.each do |key, value|
                    @data[key.to_s] << value
                end
#              
                return true
            else
                raise TypeError, "Expected an Array or a Hash"
            end
        end
        alias :<< :add_row
        
        def add_column(name, values=nil)
            raise "Column already exists" if @labels.include?(name)
            raise "Values or block required" if !values && !block_given?
            raise "Number of values not matching" if values && values.size != self.rows
            
            @labels << name
            if values
                @data[name] = values.clone
            else
                @data[name] = []
                self.each_with_index do |row, i|
                    @data[name][i] = yield row
                end
            end
        end
        
        def each
            self.each_with_index do |element, i|
                yield element
            end
            
            return self
        end
        
        def each_with_index
            for i in 0...self.rows
                element = {}
                @labels.each do |label|
                    element[label] = @data[label][i]
                end
                
                yield element, i
            end
            
            return self
        end
        
        def load_in_r_as(variable_name)
            command = []
            
            command << "#{variable_name} <- data.frame()"
            row_index = 1
            self.each do |row|
                command << "#{variable_name}[#{row_index.to_R}, #{row.keys.to_R}] <- #{row.values.to_R}"
                
                row_index += 1
            end
            
            Rust._eval_big(command)
        end
        
        def inspect
            separator = " | "
            col_widths = self.column_names.map { |colname| [colname, ([colname.length] + @data[colname].map { |e| e.inspect.length }).max] }.to_h
            col_widths[:rowscol] = (self.rows - 1).inspect.length + 3
            
            result = ""
            result << "-" * (col_widths.values.sum + ((col_widths.size - 1) * separator.length)) + "\n"
            result << (" " * col_widths[:rowscol]) + self.column_names.map { |colname| (" " * (col_widths[colname] - colname.length)) + colname }.join(separator) + "\n"
            result << "-" * (col_widths.values.sum + ((col_widths.size - 1) * separator.length)) + "\n"
            self.each_with_index do |row, i|
                index_part = "[" + (" " * (col_widths[:rowscol] - i.inspect.length - 3)) + "#{i}] "
                row_part   = row.map { |colname, value| (" " * (col_widths[colname] - value.inspect.length)) + value.inspect }.join(separator)
                
                result << index_part + row_part + "\n"
            end
            
            result << "-" * (col_widths.values.sum + ((col_widths.size - 1) * separator.length))
            
            return result
        end
        
        def head(n=10)
            result = DataFrame.new(self.column_names)
            self.each_with_index do |row, i|
                result << row if i < n
            end
            return result
        end
        
        def merge(other, by, first_alias = "x", second_alias = "y")
            raise TypeError, "Expected Rust::DataFrame" unless other.is_a?(DataFrame)
            raise TypeError, "Expected list of strings" if !by.is_a?(Array) || !by.all? { |e| e.is_a?(String) }
            raise "This dataset should have all the columns in #{by}" unless (by & self.column_names).size == by.size
            raise "The passed dataset should have all the columns in #{by}" unless (by & other.column_names).size == by.size
            
            if first_alias == second_alias
                if first_alias == ""
                    my_columns = self.column_names - by
                    other_columns = other.column_names - by
                    intersection = my_columns & other_columns
                    raise "Cannot merge because the following columns would overlap: #{intersection}" if intersection.size > 0
                else
                    raise "The aliases can not have the same value"
                end
            end
            
            my_keys = {}
            self.each_with_index do |row, i|
                key = []
                by.each do |colname|
                    key << row[colname]
                end
                
                my_keys[key] = i
            end
            
            merged_column_self  = (self.column_names - by)
            merged_column_other = (other.column_names - by)
            
            first_alias =  first_alias + "."     if first_alias.length > 0
            second_alias = second_alias + "."    if second_alias.length > 0
            
            merged_columns = merged_column_self.map { |colname| "#{first_alias}#{colname}" } + merged_column_other.map { |colname| "#{second_alias}#{colname}" }
            columns = by + merged_columns
            result = DataFrame.new(columns)
            other.each do |other_row|
                key = []
                by.each do |colname|
                    key << other_row[colname]
                end
                
                my_row_index = my_keys[key]
                if my_row_index
                    my_row = self[my_row_index]
                    
                    to_add = {}
                    by.each do |colname|
                        to_add[colname] = my_row[colname]
                    end
                    
                    merged_column_self.each do |colname|
                        to_add["#{first_alias}#{colname}"] = my_row[colname]
                    end
                    
                    merged_column_other.each do |colname|
                        to_add["#{second_alias}#{colname}"] = other_row[colname]
                    end
                    
                    result << to_add
                end
            end
            
            return result
        end
        
        def bind_rows!(dataframe)
            raise TypeError, "DataFrame expected" unless dataframe.is_a?(DataFrame)
            raise "The columns are not compatible: #{self.column_names - dataframe.column_names} - #{dataframe.column_names - self.column_names}" unless (self.column_names & dataframe.column_names).size == self.columns
            
            dataframe.each do |row|
                self << row
            end
            
            return true
        end
        alias :rbind! :bind_rows!
        
        def bind_columns!(dataframe)
            raise TypeError, "DataFrame expected" unless dataframe.is_a?(DataFrame)
            raise "The number of rows are not compatible" if self.rows != dataframe.rows
            raise "The dataset would override some columns" if (self.column_names & dataframe.column_names).size > 0
            
            dataframe.column_names.each do |column_name|
                self.add_column(column_name, dataframe.column(column_name))
            end
            
            return true
        end
        alias :cbind! :bind_columns!
        
        def bind_rows(dataframe)
            result = self.clone
            result.bind_rows!(dataframe)
            return result
        end
        alias :rbind :bind_rows
        
        def bind_columns(dataframe)
            result = self.clone
            result.bind_columns!(dataframe)
            return result
        end
        alias :cbind :bind_columns
        
        def clone
            DataFrame.new(@data)
        end
    end
    
    class Matrix < RustDatatype
        def self.pull_variable(variable)
            return Rust._pull(variable)
        end
        
        def initialize(data)
            if data.flatten.size == 0
                raise "Empty matrices are not allowed"
            else
                raise TypeError, "Expected array of array" unless data.is_a?(Array) && data[0].is_a?(Array)
                raise TypeError, "Only numeric matrices are supported" unless data.all? { |row| row.all?  { |e| e.is_a?(Numeric) } }
                raise "All the rows must have the same size" unless data.map { |row| row.size }.uniq.size == 1
                @data = data.clone
            end
        end
        
        def [](i, j)
            return @data[i][j]
        end
        
        def rows
            @data.size
        end
        
        def cols
            @data[0].size
        end
        
        def []=(i, j, value)
            raise "Wrong i" unless i.between?(0, @data.size - 1)
            raise "Wrong j" unless j.between?(0, @data[0].size - 1)
            @data[i][j] = value
        end
        
        def load_in_r_as(variable_name)
            Rust._eval("#{variable_name} <- matrix(c(#{@data.flatten.join(",")}), nrow=#{self.rows}, ncol=#{self.cols}, byrow=T)")
        end
    end
    
    class CSV
        def self.read_all(pattern, **options)
            result = {}
            Dir.glob(pattern).each do |filename|
                result[filename] = CSV.read(filename, **options)
            end
            return result
        end
        
        def self.read(filename, **options)
            hash = {}
            labels = nil
            
            ::CSV.foreach(filename, **options) do |row|
                # TODO fix this ugly patch
                unless options[:headers]
                    options[:headers] = (1..row.size).to_a.map { |e| "X#{e}" }
                    
                    return CSV.read(filename, **options)
                end
                
                unless labels
                    labels = row.headers
                    labels.each do |label|
                        hash[label] = []
                    end
                end
                
                labels.each do |label|
                    hash[label] << row[label]
                end
            end
            
            return Rust::DataFrame.new(hash)
        end
        
        def self.write(filename, dataframe, **options)
            raise TypeError, "Expected Rust::DataFrame" unless dataframe.is_a?(Rust::DataFrame)
            
            write_headers = options[:headers] != false
            options[:headers] = dataframe.column_names if options[:headers] == nil
            
            hash = {}
            labels = nil
            ::CSV.open(filename, 'w', write_headers: write_headers, **options) do |csv|
                dataframe.each do |row|
                    csv << row
                end
            end
            
            return true
        end
    end
    
    class Sequence
        attr_reader :min
        attr_reader :max
        
        def initialize(min, max, step=1)
            @min = min
            @max = max
            @step = step
        end
        
        def step(step)
            @step = step
        end
        
        def each
            (@min..@max).step(@step) do |v|
                yield v
            end
        end
        
        def to_a
            result = []
            self.each do |v|
                result << v
            end
            return result
        end
        
        def to_R
            "seq(from=#@min, to=#@max, by=#@step)"
        end
    end
end

class TrueClass
    def to_R
        "TRUE"
    end
end

class FalseClass
    def to_R
        "FALSE"
    end
end

class Object
    def to_R
        raise TypeError, "Unsupported type for #{self.class}"
    end
end

class NilClass
    def to_R
        return "NULL"
    end
end

class Numeric
    def to_R
        self.inspect
    end
end

class Float
    def to_R
        return self.nan? ? "NA" : super
    end
end

class Array
    def to_R
        return "c(#{self.map { |e| e.to_R }.join(",")})"
    end
end

class String
    def to_R
        return self.inspect
    end
end

class Range
    def to_R
        [range.min, range.max].to_R
    end
end

module Rust::RBindings
    def read_csv(filename, **options)
        Rust::CSV.read(filename, **options)
    end
    
    def write_csv(filename, dataframe, **options)
        Rust::CSV.write(filename, dataframe, **options)
    end
    
    def data_frame(*args)
        Rust::DataFrame.new(*args)
    end
end
