require 'code-assertions'
require 'stringio'
require 'rinruby'
require 'csv'

module Rust
    CLIENT_MUTEX = Mutex.new
    R_MUTEX      = Mutex.new
    
    R_ENGINE     = RinRuby.new(echo: false)
    
    private_constant    :R_ENGINE
    private_constant    :R_MUTEX
    private_constant    :CLIENT_MUTEX
    
    @@debugging = false
    @@in_client_mutex = false
    
    def self.debug
        @@debugging = true
    end
    
    def self.debug?
        return @@debugging
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
        elsif value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(Array) || value.is_a?(::Matrix)
            R_ENGINE.assign(variable, value)
        else
            raise "Trying to assign #{variable} with #{value.class}; expected RustDatatype, String, Numeric, or Array"
        end
        
    end
    
    def self.[](variable)
        return RustDatatype.pull_variable(variable)
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
                puts " Got #{warnings.size} warnings, with result #{result.inspect[0...100]}" if @@debugging
                return result, warnings.lines.map { |w| w.strip.chomp }
            else
                puts " Result: #{result.inspect[0...100]}" if @@debugging
                return result
            end
        end
    end
    
    def self.check_library(name)
        self.exclusive do
            result, _ = self._pull("require(\"#{name}\", character.only = TRUE)", true)
            return result
        end
    end
    
    def self.load_library(name)
        self.exclusive do
            self._eval("library(\"#{name}\", character.only = TRUE)")
        end
        
        return nil
    end
    
    def self.install_library(name)
        self.exclusive do
            self._eval("install.packages(\"#{name}\", dependencies = TRUE)")
        end
        
        return nil
    end
    
    def self.prerequisite(library)
        self.install_library(library) unless self.check_library(library)
        self.load_library(library)
    end
    
    class RustDatatype
        def self.pull_variable(variable, forced_interpreter = nil)
            r_type = Rust._pull("as.character(typeof(#{variable}))")
            r_class = Rust._pull("as.character(class(#{variable}))")
            
            if forced_interpreter
                raise ArgumentError, "Expected null or class as forced_interpreter" if forced_interpreter && !forced_interpreter.is_a?(Class)
                raise ArgumentError, "Class #{forced_interpreter} can not handle type #{r_type}, class #{r_class}" unless forced_interpreter.can_pull?(r_type, r_class)
                
                return forced_interpreter.pull_variable(variable, r_type, r_class)
            end
            
            candidates = []
            ObjectSpace.each_object(Class) do |type|
                if type < RustDatatype
                    if type.can_pull?(r_type, r_class)
                        candidates << type
                    end
                end
            end
            
            if candidates.size > 0
                type = candidates.max_by { |c| c.pull_priority }
                
                puts "Using #{type} to pull #{variable}" if Rust.debug?
                return type.pull_variable(variable, r_type, r_class)
            else
                if Rust._pull("length(#{variable})") == 0
                    return []
                else
                    return Rust._pull(variable)
                end
            end
        end
        
        def self.pull_priority
            0
        end
        
        def load_in_r_as(variable_name)
            raise "Loading #{self.class} in R was not implemented"
        end
        
        def r_mirror_to(other_variable)
            varname = self.mirrored_R_variable_name
            
            Rust._eval("#{varname} = #{other_variable}")
            Rust["#{varname}.hash"] = self.r_hash
                        
            return varname
        end
        
        def r_mirror
            varname = self.mirrored_R_variable_name
                        
            if !Rust._pull("exists(\"#{varname}\")") || Rust._pull("#{varname}.hash") != self.r_hash
                puts "Loading #{varname}" if Rust.debug?
                Rust[varname] = self
                Rust["#{varname}.hash"] = self.r_hash
            else
                puts "Using cached value for #{varname}" if Rust.debug?
            end
            
            return varname
        end
        
        def r_hash
            self.hash.to_s
        end
        
        private
        def mirrored_R_variable_name
            return "rust.mirrored.#{self.object_id}"
        end
    end
    
    class S4Class < RustDatatype
        def self.can_pull?(type, klass)
            return type == "S4"
        end
        
        def self.pull_variable(variable, type, klass)
            slots = [Rust._pull("names(getSlots(\"#{klass}\"))")].flatten
            
            return S4Class.new(variable, klass, slots)
        end
        
        def load_in_r_as(variable_name)
            Rust._eval("#{variable_name} <- #{self.r_mirror}")
        end
        
        def r_hash
            "immutable"
        end
        
        def initialize(variable_name, klass, slots)
            @klass = klass
            @slots = slots
            
            self.r_mirror_to(variable_name)
        end
        
        def [](key)
            raise ArgumentError, "Unknown slot `#{key}` for class `#@klass`" unless @slots.include?(key)
            
            Rust.exclusive do
                return Rust["#{self.r_mirror}@#{key}"]
            end
        end
        alias :| :[]
        
        def []=(key, value)
            raise ArgumentError, "Unknown slot `#{key}` for class `#@klass`" unless @slots.include?(key)
            
            Rust.exclusive do
                return Rust["#{self.r_mirror}@#{key}"] = value
            end
        end
        
        def slots
            @slots
        end
        
        def class_name
            @klass
        end
        
        def inspect
            return "<S4 instance of #@klass, with slots #@slots>"
        end
    end
    
    class List < RustDatatype
        def self.can_pull?(type, klass)
            return type == "list" && klass != "data.frame"
        end
        
        def self.pull_variable(variable, type, klass)
            return List.new(klass) if Rust._pull("length(#{variable})") == 0
            
            names    = [Rust["names(#{variable})"]].flatten
            length   = Rust["length(#{variable})"]
            
            list = List.new(klass, names)
            for i in 0...length
                list[i] = Rust["#{variable}[[#{i + 1}]]"]
            end
            
            return list
        end
        
        def load_in_r_as(variable_name)
            Rust._eval("#{variable_name} <- list()")
            @data.each do |key, value|
                Rust["#{variable_name}[[#{key + 1}]]"] = value
            end
        end
        
        def initialize(klass, names = [])
            @data = {}
            @names = names
            @klass = klass
        end
        
        def [](key)
            key = get_key(key)
            
            return @data[key]
        end
        alias :| :[]
        
        def []=(key, value)
            key = get_key(key)
            
            return @data[key] = value
        end
        
        def names
            @names
        end
        
        def inspect
            result = ""
            values_inspected = @data.map { |k, v| [k, v.inspect.split("\n").map { |l| "  " + l }.join("\n")] }.to_h
            max_length = [values_inspected.map { |k, v| v.split("\n").map { |line| line.length }.max.to_i }.max.to_i, 100].min
            
            @data.keys.each do |i|
                result << "-" * max_length + "\n"
                result << (@names[i] || "[[#{i}]]") + "\n"
                result << values_inspected[i] + "\n"
            end
            result << "-" * max_length
            
            return result
        end
        
        private
        def get_key(key)
            if key.is_a?(String)
                new_key = @names.index(key)
                raise ArgumentError, "Wrong key: #{key}" unless new_key
                key = new_key
            end
            
            raise ArgumentError, "The key should be either a string or an integer" unless key.is_a?(Integer)
            
            return key
        end
    end
    
    class DataFrame < RustDatatype
        def self.can_pull?(type, klass)
            return [klass].flatten.include?("data.frame")
        end
        
        def self.pull_variable(variable, type, klass)
            hash = {}
            colnames = Rust["colnames(#{variable})"]
            colnames.each do |col|
                hash[col] = Rust["#{variable}$\"#{col}\""]
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
                
                labels_or_data.each do |key, value|
                    @data[key.to_s] = value.clone
                end
            end
        end
        
        def row(i)
            if i < 0 || i >= self.rows
                return nil
            else
                return @data.map { |label, values| [label, values[i]] }.to_h
            end
        end
        
        def fast_row(i)
            if i < 0 || i >= self.rows
                return nil
            else
                return @labels.map { |label| @data[label][i] }
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
        alias :| :column
        
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
        
        def has_row?
            self.each_with_index do |row, i|
                return true if yield row, i
            end
            return false
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
        
        def delete_row(i)
            @data.each do |label, column|
                column.delete_at(i)
            end
        end
        
        def uniq_by(by)
            result = self.clone
            result.uniq_by!(by)
            return result
        end
        
        def uniq_by!(by)
            my_keys = {}
            to_delete = []
            self.each_with_index do |row, i|
                key = []
                by.each do |colname|
                    key << row[colname]
                end
                unless my_keys[key]
                    my_keys[key] = i
                else
                    to_delete << (i-to_delete.size)
                end
            end
            
            to_delete.each do |i|
                self.delete_row(i)
            end
            
            return self
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
        
        def fast_each
            self.fast_each_with_index do |element, i|
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
        
        def fast_each_with_index
            for i in 0...self.rows
                element = []
                @labels.each do |label|
                    element << @data[label][i]
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
            
            self.column_names.each do |name|
                column = self.column(name)
                
                if column.is_a?(Factor)
                    command << "#{variable_name}[,#{name.to_R}] <- factor(#{variable_name}[,#{name.to_R}], labels=#{column.levels.to_R})"
                end
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
                    my_row = self.row(my_row_index)
                    
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
        
        def aggregate(by, **aggregators)
            raise TypeError, "Expected a string" unless by.is_a?(String)
            raise TypeError, "All the aggregators should be procs" unless aggregators.values.all? { |v| v.is_a?(Proc) }
            raise "Expected a block for default aggregator" unless block_given?
            
            aggregators = aggregators.map { |label, callable| [label.to_s, callable] }.to_h
            
            sorted = self.sort_by(by)
            
            current_value = nil
            partials = []
            partial = nil
            sorted.column(by).each_with_index do |value, index|
                if current_value != value
                    current_value = value
                    partials << partial if partial
                    partial = Rust::DataFrame.new(self.column_names)
                end
                partial << sorted.fast_row(index)
            end
            partials << partial
            
            result = Rust::DataFrame.new(self.column_names)
            partials.each do |partial|
                aggregated_row = {}
                aggregated_row[by] = partial.column(by)[0]
                (self.column_names - [by]).each do |column|
                    if aggregators[column]
                        aggregated_row[column] = aggregators[column].call(partial.column(column))
                    else
                        aggregated_row[column] = yield partial.column(column)
                    end
                end
                
                result << aggregated_row
            end
            
            return result
        end
        
        def sort_by(column)
            result = self.clone
            result.sort_by!(column)
            return result
        end
        
        def sort_by!(by)
            copy = @data[by].clone
            copy.sort!
            
            indices = []
            @data[by].each_with_index do |value, i|
                index = copy.index(value)
                indices << index
                
                copy[index] = NilClass
            end
                        
            (self.column_names - [by]).each do |column_name|
                sorted = []
                column = self.column(column_name)
                column_i = 0
                indices.each do |i|
                    sorted[i] = column[column_i]
                    column_i += 1
                end
                @data[column_name] = sorted
            end
            @data[by].sort!
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
        def self.can_pull?(type, klass)
            return klass.is_a?(Array) && klass.include?("matrix")
        end
        
        def self.pull_variable(variable, type, klass)
            if Rust._pull("length(#{variable})") == 1
                core = ::Matrix[[Rust._pull("#{variable}[1]")]]
            else
                core = Rust._pull(variable)
            end
            row_names = [Rust["rownames(#{variable})"]].flatten
            column_names = [Rust["colnames(#{variable})"]].flatten
            
            row_names = nil if row_names.all? { |v| v == nil }
            column_names = nil if column_names.all? { |v| v == nil }
            
            Matrix.new(core, row_names, column_names)
        end
        
        def load_in_r_as(variable_name)
            matrix = ::Matrix[*@data]
            
            Rust[variable_name] = matrix
        end
        
        def initialize(data, row_names = nil, column_names = nil)
            @data = data.clone
            
            @row_names = row_names
            @column_names = column_names
            
            if @data.is_a?(::Matrix)
                @data = @data.row_vectors.map { |v| v.to_a }
            end
            
            if self.flatten.size == 0
                raise "Empty matrices are not allowed"
            else
                raise TypeError, "Expected array of array" unless @data.is_a?(Array) || @data[0].is_a?(Array)
                raise TypeError, "Only numeric matrices are supported" unless self.flatten.all? { |e| e.is_a?(Numeric) }
                raise "All the rows must have the same size" unless @data.map { |row| row.size }.uniq.size == 1
                raise ArgumentError, "Expected row names #@row_names to match the number of rows in #{self.inspect}" if @row_names && @row_names.size != self.rows
                raise ArgumentError, "Expected column names #@column_names to match the number of columns in #{self.inspect}" if @column_names && @column_names.size != self.cols
            end
        end
        
        def [](i, j)
            i, j = indices(i, j)
            
            return @data[i][j]
        end
        
        def rows
            @data.size
        end
        
        def cols
            @data[0].size
        end
        
        def flatten
            return @data.flatten
        end
        
        def []=(i, j, value)
            i, j = indices(i, j)
            
            @data[i][j] = value
        end
        
        def inspect
            row_names = @row_names || (0...self.rows).to_a.map { |v| v.to_s }
            column_names = @column_names || (0...self.cols).to_a.map { |v| v.to_s }
            
            separator = " | "
            col_widths = column_names.map do |colname| 
                [
                    colname, 
                    (
                        [colname ? colname.length : 1] + 
                        @data.map {|r| r[column_names.index(colname)]}.map { |e| e.inspect.length }
                    ).max
                ]
            end.to_h
            col_widths[:rowscol] = row_names.map { |rowname| rowname.length }.max + 3
            
            result = ""
            result << "-" * (col_widths.values.sum + ((col_widths.size - 1) * separator.length)) + "\n"
            result << (" " * col_widths[:rowscol]) + column_names.map { |colname| (" " * (col_widths[colname] - colname.length)) + colname }.join(separator) + "\n"
            result << "-" * (col_widths.values.sum + ((col_widths.size - 1) * separator.length)) + "\n"
            
            @data.each_with_index do |row, i|
                row_name = row_names[i]
                row = column_names.zip(row)
                
                index_part = "[" + (" " * (col_widths[:rowscol] - row_name.length - 3)) + "#{row_name}] "
                row_part   = row.map { |colname, value| (" " * (col_widths[colname] - value.inspect.length)) + value.inspect }.join(separator)
                
                result << index_part + row_part + "\n"
            end
            
            result << "-" * (col_widths.values.sum + ((col_widths.size - 1) * separator.length))
            
            return result
        end
        
        private
        def indices(i, j)
            if i.is_a?(String)
                ri = @row_names.index(i)
                raise ArgumentError, "Can not find row #{i}" unless ri
                i = ri
            end
            
            if j.is_a?(String)
                rj = @column_names.index(j)
                raise ArgumentError, "Can not find column #{j}" unless rj
                j = rj
            end
            
            raise ArgumentError, "Expected i and j to be both integers or strings" unless i.is_a?(Integer) && j.is_a?(Integer)
            raise "Wrong i" unless i.between?(0, @data.size - 1)
            raise "Wrong j" unless j.between?(0, @data[0].size - 1)
            
            return [i, j]
        end
    end
    
    class Sequence < RustDatatype
        attr_reader :min
        attr_reader :max
        
        def self.can_pull?(type, klass)
            return false
        end
        
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
        
        def load_in_r_as(variable_name)
            Rust._eval("#{variable_name} <- #{self.to_R}")
        end
    end
    
    class DataFrameArray < Array
        def bind_all
            return nil if self.size == 0
            
            result = self.first.clone
            
            for i in 1...self.size
                result .bind_rows!(self[i])
            end
            
            return result
        end
    end
    
    class DataFrameHash < Hash
        def bind_all
            return nil if self.values.size == 0
            
            result = self.values.first.clone
            
            for i in 1...self.values.size
                result .bind_rows!(self.values[i])
            end
            
            return result
        end
    end
    
    class MathArray < Array
        def -(other)
            raise ArgumentError, "Expected array or numeric" if !other.is_a?(::Array) && !other.is_a?(Numeric)
            raise ArgumentError, "The two arrays must have the same size" if other.is_a?(::Array) && self.size != other.size
            
            result = self.clone
            other = [other] * self.size if other.is_a?(Numeric)
            for i in 0...self.size
                result[i] -= other[i]
            end
            
            return result
        end
        
        def *(other)
            raise ArgumentError, "Expected array or numeric" if !other.is_a?(::Array) && !other.is_a?(Numeric)
            raise ArgumentError, "The two arrays must have the same size" if other.is_a?(::Array) && self.size != other.size
            
            result = self.clone
            other = [other] * self.size if other.is_a?(Numeric)
            for i in 0...self.size
                result[i] *= other[i]
            end
            
            return result
        end
                
        def +(other)
            raise ArgumentError, "Expected array or numeric" if !other.is_a?(::Array) && !other.is_a?(Numeric)
            raise ArgumentError, "The two arrays must have the same size" if other.is_a?(::Array) && self.size != other.size
            
            result = self.clone
            other = [other] * self.size if other.is_a?(Numeric)
            for i in 0...self.size
                result[i] += other[i]
            end
            
            return result
        end
        
        def /(other) #/# <- this comment is just to recover the syntax highlighting bug in Kate
            raise ArgumentError, "Expected array or numeric" if !other.is_a?(::Array) && !other.is_a?(Numeric)
            raise ArgumentError, "The two arrays must have the same size" if other.is_a?(::Array) && self.size != other.size
            
            result = self.clone
            other = [other] * self.size if other.is_a?(Numeric)
            for i in 0...self.size
                result[i] /= other[i]
            end
            
            return result
        end
        
        def **(other)
            raise ArgumentError, "Expected numeric" if !other.is_a?(Numeric)
            
            result = self.clone
            for i in 0...self.size
                result[i] = result[i] ** other
            end
            
            return result
        end
    end
        
    class Formula < RustDatatype
        def self.can_pull?(type, klass)
            return klass == "formula" || (klass.is_a?(Array) && klass.include?("formula"))
        end
        
        def self.pull_variable(variable, type, klass)
            formula_elements = Rust._pull("as.character(#{variable})")

            assert("The number of elements of a formula must be 2 or 3: #{formula_elements} given") { formula_elements.size > 1 && formula_elements.size < 4 }
            if formula_elements.size == 2
               return Formula.new(nil, formula_elements[1]) 
            elsif formula_elements.size == 3
                return Formula.new(formula_elements[2], formula_elements[1])
            end
        end
        
        def load_in_r_as(variable_name)
            Rust._eval("#{variable_name} <- #{self.left_part} ~ #{self.right_part}")
        end
        
        attr_reader     :left_part
        attr_reader     :right_part
        
        def initialize(left_part, right_part)
            raise ArgumentError, "Expected string" if left_part && !left_part.is_a?(String)
            raise ArgumentError, "Expected string" if !right_part.is_a?(String)
            
            @left_part  = left_part || ""
            @right_part = right_part
        end
        
        def ==(oth)
            return false unless oth.is_a?(Formula)
            
            return @left_part == oth.left_part && @right_part == oth.right_part
        end
        
        def to_R
            return "#@left_part ~ #@right_part"
        end
        
        def inspect
            return self.to_R.strip
        end
    end
    
    class Factor < RustDatatype
        def self.can_pull?(type, klass)
            return klass == "factor"
        end
        
        def self.pull_variable(variable, type, klass)
            levels = Rust["levels(#{variable})"]
            values = Rust["as.integer(#{variable})"]
            
            return Factor.new(values, levels)
        end
        
        def load_in_r_as(variable_name)
            Rust['tmp.levels'] = @levels.map { |v| v.to_s }
            Rust['tmp.values'] = @values
            
            Rust._eval("#{variable_name} <- factor(tmp.values, labels=tmp.levels)")
        end
        
        def initialize(values, levels)
            @levels = levels.map { |v| v.to_sym }
            @values = values
        end
        
        def levels
            @levels
        end
        
        def ==(other)
            return false unless other.is_a?(Factor)
            
            return @levels == other.levels && self.to_a == other.to_a
        end
        
        def [](i)
            FactorValue.new(@values[i], @levels[@values[i] - 1])
        end
        
        def []=(i, value)
            raise "The given value is outside the factor bounds" if value.is_a?(Integer) && (value < 1 || value > @levels.size)
            
            if value.is_a?(FactorValue)
                raise "Incompatible factor value, different levels used" unless @levels.include?(value.level) || @levels.index(value.level) + 1 == @value.value
                value = value.value
            end
            
            if value.is_a?(String) || value.is_a?(Symbol)
                value = value.to_sym
                raise "Unsupported value #{value}; expected #{@levels.join(", ")}" unless @levels.include?(value)
                
                value = @levels.index(value) + 1
            end
            
            @values[i] = value
        end
        
        def to_a
            @values.map { |v| FactorValue.new(v, @levels[v - 1]) }
        end
        
        def method_missing(method, *args, &block)
            raise NoMethodError, "Undefined method #{method} for Factor" if method.to_s.end_with?("!") || method.end_with?("=")
            
            self.to_a.method(method).call(*args, &block)
        end
        
        def to_s
            self.to_a.to_s
        end
        
        def inspect
            self.to_a.inspect
        end
    end
    
    class FactorValue
        def initialize(value, level)
            @value = value
            @level = level
        end
        
        def value
            @value
        end
        
        def level
            @level
        end
        
        def to_i
            @value
        end
        
        def to_sym
            @level
        end
        
        def to_R
            self.to_i
        end
        
        def inspect
            @level.inspect
        end
        
        def ==(other)
            if other.is_a?(FactorValue)
                @value == other.value && @level == other.level
            elsif other.is_a?(Integer)
                @value == other
            elsif other.is_a?(Symbol)
                @level == other
            end
        end
        
        def hash
            @value.hash + @level.hash
        end
        
        def eql?(other)
            return self == other
        end
        
        def method_missing(method, *args, &block)
            @level.method(method).call(*args, &block)
        end
    end
        
    class Call < RustDatatype
        def self.can_pull?(type, klass)
            return klass == "call"
        end
        
        def self.pull_variable(variable, type, klass)
            return Call.new(Rust["deparse(#{variable})"])
        end
        
        def load_in_r_as(variable_name)
            Rust["call.str"] = @value
            Rust._eval("#{variable_name} <- str2lang(call.str)")
        end
        
        def initialize(value)
            @value = value
        end
        
        def value
            @value
        end
        
        def inspect
            @value
        end
    end
    
    class Null < RustDatatype
        def self.can_pull?(type, klass)
            return type == "NULL" && klass == "NULL"
        end
        
        def self.pull_variable(variable, type, klass)
            return nil
        end
    end
    
    class Environment < RustDatatype
        def self.can_pull?(type, klass)
            return type == "environment" && klass == "environment"
        end
        
        def self.pull_variable(variable, type, klass)
            warn "Exchanging R environments is not supported!"
            return Environment.new
        end
        
        def self.load_in_r_as(variable)
            warn "Exchanging R environments is not supported!"
            Rust._eval("#{variable} <- environment()")
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
    
    def load_in_r_as(variable)
        Rust._eval("#{variable} <- NULL")
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

class Symbol
    def to_R
        return self.to_s.inspect
    end
end

class Array
    def to_R
        return "c(#{self.map { |e| e.to_R }.join(",")})"
    end
    
    def distribution
        result = {}
        self.each do |value|
            result[value] = result[value].to_i + 1
        end
        return result
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
    def data_frame(*args)
        Rust::DataFrame.new(*args)
    end
end

module Rust::TestCases
    def self.sample_dataframe(columns, size=100)
        result = Rust::DataFrame.new(columns)
        size.times do |i|
            result << columns.map { |c| yield i, c }
        end
        return result
    end
end

def bind_r!
    include Rust::RBindings
end
