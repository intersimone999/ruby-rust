require_relative 'datatype'

module Rust
    
    ##
    # Mirror of the matrix type in R.
    
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
        
        ##
        # Creates a new matrix with the given +data+ (Ruby Matrix). Optionally, +row_names+ and +column_names+ can 
        # be specified.
        
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
        
        ##
        # Returns the matrix element at row +i+ and column +j+.
        
        def [](i, j)
            i, j = indices(i, j)
            
            return @data[i][j]
        end
        
        ##
        # Sets the matrix element at row +i+ and column +j+ with +value+.
        
        def []=(i, j, value)
            i, j = indices(i, j)
            
            @data[i][j] = value
        end
        
        ##
        # Returns the number of rows.
        
        def rows
            @data.size
        end
        
        def rownames
            @row_names
        end
        
        def colnames
            @column_names
        end
        
        ##
        # Returns the number of columns.
        
        def cols
            @data[0].size
        end
        
        ##
        # Returns a flattened version of the matrix (Array).
        
        def flatten
            return @data.flatten
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
end
