require_relative 'datatype'

module Rust
    
    ##
    # Mirror of the data-frame type in R.
    
    class DataFrame < RustDatatype
        def self.can_pull?(type, klass)
            return [klass].flatten.include?("data.frame")
        end
        
        def self.pull_priority
            1
        end
        
        def self.pull_variable(variable, type, klass)
            hash = {}
            colnames = Rust["colnames(#{variable})"]
            colnames.each do |col|
                hash[col] = Rust["#{variable}$\"#{col}\""]
            end
            return DataFrame.new(hash)
        end
        
        ##
        # Creates a new data-frame.
        # +labels_or_data+ can be either:
        # - an Array of column names (creates an empty data-frame)
        # - a Hash with column names as keys and values as values
        
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
        
        ##
        # Returns the +i+-th row of the data-frame
        
        def row(i)
            if i < 0 || i >= self.rows
                return nil
            else
                return @data.map { |label, values| [label, values[i]] }.to_h
            end
        end
        
        ##
        # Returns the +i+-th row of the data-frame. Faster (but harder to interpret) alternative to #row.
        
        def fast_row(i)
            if i < 0 || i >= self.rows
                return nil
            else
                return @labels.map { |label| @data[label][i] }
            end
        end
        
        ##
        # Shuffles the rows in the data-frame. The arguments are passed to the Array#shuffle method.
        
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
        
        ##
        # Returns a copy of the data-frame containing only the specified +rows+ and/or +cols+. If +rows+ and/or +cols+
        # are nil, all the rows/columns are returned.
        
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
        
        ##
        # Return the column named +name+.
        
        def column(name)
            return @data[name]
        end
        alias :| :column
        
        ##
        # Renames the column named +old_name+ in +new_name+.
        
        def rename_column!(old_name, new_name)
            raise "This DataFrame does not contain a column named #{old_name}" unless @labels.include?(old_name)
            raise "This DataFrame already contains a column named #{new_name}" if @labels.include?(new_name)
            
            @data[new_name.to_s] = @data.delete(old_name)
            @labels[@labels.index(old_name)] = new_name
        end
        
        ##
        # Functionally transforms the column named +column+ by applying the function given as a block.
        # Example:
        # df = Rust::DataFrame.new({a: [1,2,3], b: [3,4,5]})
        # df.transform_column!("a") { |v| v + 1 }
        # df|"a" # => [2, 3, 4]
        
        def transform_column!(column)
            @data[column].map! { |e| yield e }
        end
        
        ##
        # Returns a copy data-frame with only the rows for which the function given in the block returns true.
        # Example:
        # df = Rust::DataFrame.new({a: [1,2,3], b: ['a','b','c']})
        # df2 = df.select_rows { |r| r['a'].even? }
        # df2|"b" # => ['b']
        
        def select_rows
            result = DataFrame.new(self.column_names)
            self.each_with_index do |row, i|
                result << row if yield row, i
            end
            return result
        end
        
        ##
        # Returns true if the function given in the block returns true for any of the rows in this data-frame.
        
        def has_row?
            self.each_with_index do |row, i|
                return true if yield row, i
            end
            return false
        end
        
        ##
        # Returns a copy of the data-frame with only the columns in +cols+. As an alternative, a block can be used 
        # (only the columns for which the function returns true are kept).
        
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
        
        ##
        # Deletes the column named +column+.
        
        def delete_column(column)
            @labels.delete(column)
            @data.delete(column)
        end
        
        ##
        # Deletes the +i+-th row.
        
        def delete_row(i)
            @data.each do |label, column|
                column.delete_at(i)
            end
        end
        
        ##
        # Returns a data-frame in which the rows are unique in terms of all the given columns named +by+.
        
        def uniq_by(by)
            result = self.clone
            result.uniq_by!(by)
            return result
        end
        
        ##
        # Makes sure that in this data-frame the rows are unique in terms of all the given columns named +by+.
        
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
        
        ##
        # Return the names of the columns.
        
        def column_names
            return @labels.map { |k| k.to_s }
        end
        alias :colnames :column_names
        
        ##
        # Returns the number of rows.
        
        def rows
            @data.values[0].size
        end
        
        ##
        # Returns the number of columns
        
        def columns
            @labels.size
        end
        
        ##
        # Adds the given +row+ to the data-frame. +row+ can be either:
        # - An Array of values for all the columns (in the order of #column_names);
        # - A Hash containing associations between column names and value to be set.
        
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
        
        ##
        # Adds a column named +name+ with the given +values+ (array). The size of +values+ must match the number of
        # rows of this data-frame. As an alternative, it can be passed a block which returns, for a given row, the
        # value to assign for the new column.
        
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
        
        ##
        # Yields each row as a Hash containing column names as keys and values as values.
        
        def each
            self.each_with_index do |element, i|
                yield element
            end
            
            return self
        end
        
        ##
        # Yields each row as a Hash containing column names as keys and values as values. Faster alternative to
        # #each.
        
        def fast_each
            self.fast_each_with_index do |element, i|
                yield element
            end
            
            return self
        end
        
        ##
        # Yields each row as a Hash containing column names as keys and values as values and the row index.
        
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
        
        ##
        # Yields each row as a Hash containing column names as keys and values as values and the row index. Faster 
        # alternative to #each_with_index.
        
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
        
        ##
        # Returns a copy of the data-frame containing only the first +n+ rows.
        
        def head(n=10)
            result = DataFrame.new(self.column_names)
            self.each_with_index do |row, i|
                result << row if i < n
            end
            return result
        end
        
        ##
        # Merges this data-frame with +other+ in terms of the +by+ column(s) (Array or String).
        # +first_alias+ and +second_alias+ allow to specify the prefix that should be used for the columns not in +by+
        # for this and the +other+ data-frame, respectively.
        
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
        
        ##
        # Aggregate the value in groups depending on the +by+ column (String). 
        # A block must be passed to specify how to aggregate the columns. Aggregators for specific columns can be
        # specified as optional arguments in which the name of the argument represents the column name and the value 
        # contains a block for aggregating the specific column.
        # Both the default and the specialized blocks must take as argument an array of values and must return a 
        # scalar value.
        
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
        
        ##
        # Returns a copy of this data-frame in which the rows are sorted by the values of the +by+ column.
        
        def sort_by(column)
            result = self.clone
            result.sort_by!(column)
            return result
        end
        
        ##
        # Sorts the rows of this data-frame by the values of the +by+ column.
        
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
        
        ##
        # Adds all the rows in +dataframe+ to this data-frame. The column names must match.
        
        def bind_rows!(dataframe)
            raise TypeError, "DataFrame expected" unless dataframe.is_a?(DataFrame)
            raise "The columns are not compatible: #{self.column_names - dataframe.column_names} - #{dataframe.column_names - self.column_names}" unless (self.column_names & dataframe.column_names).size == self.columns
            
            dataframe.each do |row|
                self << row
            end
            
            return true
        end
        alias :rbind! :bind_rows!
        
        ##
        # Adds all the columns in +dataframe+ to this data-frame. The number of rows must match.
        
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
        
        ##
        # Returns a copy of this dataframe and adds all the rows in +dataframe+ to it. The column names must match.
        
        def bind_rows(dataframe)
            result = self.clone
            result.bind_rows!(dataframe)
            return result
        end
        alias :rbind :bind_rows
        
        ##
        # Returns a copy of this dataframe and adds all the columns in +dataframe+ to it. The number of rows must match.
        
        def bind_columns(dataframe)
            result = self.clone
            result.bind_columns!(dataframe)
            return result
        end
        alias :cbind :bind_columns
        
        ##
        # Returns a copy of this data-frame.
        
        def clone
            DataFrame.new(@data)
        end
    end
    
    ##
    # Represents an array of DataFrame
    
    class DataFrameArray < Array
        
        ##
        # Returns a data-frame with the rows in all the data-frames together (if compatible).
        
        def bind_all
            return nil if self.size == 0
            
            result = self.first.clone
            
            for i in 1...self.size
                result .bind_rows!(self[i])
            end
            
            return result
        end
    end
    
    ##
    # Represents a hash of DataFrame
    
    class DataFrameHash < Hash
        
        ##
        # Returns a data-frame with the rows in all the data-frames together (if compatible).
        
        def bind_all
            return nil if self.values.size == 0
            
            result = self.values.first.clone
            
            for i in 1...self.values.size
                result .bind_rows!(self.values[i])
            end
            
            return result
        end
    end
end
