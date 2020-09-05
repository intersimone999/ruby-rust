require 'code-assertions'
require 'stringio'
require 'rinruby'
require 'csv'

module Rust
    CLIENT_MUTEX = Mutex.new
    R_MUTEX      = Mutex.new
    
    R_ENGINE     = RinRuby.new(echo: false)
    
    @@in_client_mutex = false
    
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
            raise "Given #{variable.class}, expected RustDatatype, String, Numeric, or Array"
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
                @labels.each { |label| @data[label] = [] }
                for i in 0...labels_or_data.values[0].size
                    self.add_row(labels_or_data.map { |k, v| [k, v[i]] }.to_h)
                end
            end
        end
        
        def row(i)
            return @data.map { |label, values| [label, values[i]] }.to_h
        end
        alias :[] :row
        
        def column(name)
            return @data[name]
        end
        
        def transform_column!(column)
            @data[column].map! { |e| yield e }
        end
        
        def select_rows
            result = DataFrame.new(self.column_names)
            self.each do |row|
                result << row if yield row
            end
            return result
        end
        
        def select_cols
            result = self.clone
            @labels.each do |label|
                result.delete_column(label) unless yield label
            end
            return result
        end
        
        def delete_column(column)
            @labels.delete(column)
            @data.delete(column)
        end
        
        def column_names
            return @data.keys.map { |k| k.to_s }
        end
        alias :colnames :column_names
        
        def merge(other, by, first_alias = "x", second_alias = "y")
            raise TypeError, "Expected Rust::DataFrame" unless other.is_a?(DataFrame)
            raise TypeError, "Expected list of strings" if !by.is_a?(Array) || !by.all? { |e| e.is_a?(String) }
            raise "This dataset should have all the columns in #{by}" unless (by & self.column_names).size == by.size
            raise "The passed dataset should have all the columns in #{by}" unless (by & other.column_names).size == by.size
            raise "The aliases can not have the same value" if first_alias == second_alias
            
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
        
        def rows
            @data.values[0].size
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
                keys    = row.keys.map { |v| v.inspect }.join(",")
                values  = row.values.map { |v| v.inspect }.join(",")
                command << "#{variable_name}[#{row_index}, c(#{keys})] <- c(#{values})"
                
                row_index += 1
            end
            
            Rust._eval_big(command)
        end
        
        def inspect
            separator = " | "
            col_widths = self.column_names.map { |colname| [colname, ([colname.length] + @data[colname].map { |e| e.inspect.length }).max] }.to_h
            col_widths[:rowscol] = self.rows.inspect.length + 3
            
            result = ""
            result << "-" * (col_widths.values.sum + ((col_widths.size - 1) * separator.length)) + "\n"
            result << (" " * col_widths[:rowscol]) + self.column_names.map { |colname| (" " * (col_widths[colname] - colname.length)) + colname }.join(separator) + "\n"
            result << "-" * (col_widths.values.sum + ((col_widths.size - 1) * separator.length)) + "\n"
            self.each_with_index do |row, i|
                result << "[#{i}] " + row.map { |colname, value| (" " * (col_widths[colname] - value.inspect.length)) + value.inspect }.join(separator) + "\n"
            end
            
            result << "-" * (col_widths.values.sum + ((col_widths.size - 1) * separator.length))
            
            return result
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
        def self.read(filename, **options)
            hash = {}
            labels = nil
            ::CSV.parse(File.read(filename), **options) do |row|
                labels = row.headers || (1..row.size).to_a.map { |e| "X#{e}" } unless labels
                
                labels.each do |label|
                    hash[label] = [] unless hash[label]
                    hash[label] << row[label]
                end
            end
            
            return Rust::DataFrame.new(hash)
        end
        
        def self.write(filename, dataframe, **options)
            raise TypeError, "Expected Rust::DataFrame" unless dataframe.is_a?(Rust::DataFrame)
            
            x[:headers] = dataframe.column_names if x[:headers]
            
            hash = {}
            labels = nil
            ::CSV.open(filename, 'w', write_headers: (x[:headers] ? true : false), **options) do |csv|
                dataframe.each do |row|
                    csv << row
                end
            end
            
            return true
        end
    end
end
