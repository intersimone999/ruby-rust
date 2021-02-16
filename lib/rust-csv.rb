require_relative 'rust-core'

module Rust
    class CSV
        def self.read_all(pattern, **options)
            result = DataFrameHash.new
            Dir.glob(pattern).each do |filename|
                result[filename] = CSV.read(filename, **options)
            end
            return result
        end
        
        def self.read(filename, **options)
            hash = {}
            labels = nil
            
            infer_numbers       = options.has_key?(:infer_numbers) ? options.delete(:infer_numbers) : true
            infer_integers      = options.delete(:infer_integers)
            
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
            
            result = Rust::DataFrame.new(hash)
            if infer_numbers
                result = self.auto_infer_types(result, infer_integers)
            end
            
            return result
        end
        
        def self.write(filename, dataframe, **options)
            raise TypeError, "Expected Rust::DataFrame" unless dataframe.is_a?(Rust::DataFrame)
            
            write_headers = options[:headers] != false
            options[:headers] = dataframe.column_names unless options[:headers]
            
            hash = {}
            ::CSV.open(filename, 'w', write_headers: write_headers, **options) do |csv|
                dataframe.each do |row|
                    csv << row
                end
            end
            
            return true
        end
        
        private
        def self.auto_infer_types(dataframe, auto_infer_integers)
            integer_columns = []
            float_columns   = []
            dataframe.column_names.each do |column_name|
                values = dataframe.column(column_name)
                
                if values.all? { |s| !!Integer(s) rescue false }
                    integer_columns << column_name
                elsif values.all? { |s| !!Float(s) rescue false }
                    float_columns << column_name
                end
            end
            
            unless auto_infer_integers
                float_columns += integer_columns
                integer_columns = []
            end
            
            integer_columns.each do |numeric_column|
                dataframe.transform_column!(numeric_column) { |v| v.to_i }
            end
            
            float_columns.each do |numeric_column|
                dataframe.transform_column!(numeric_column) { |v| v.to_f }
            end
            
            return dataframe
        end
    end
end

module Rust::RBindings
    def read_csv(filename, **options)
        Rust::CSV.read(filename, **options)
    end
    
    def write_csv(filename, dataframe, **options)
        Rust::CSV.write(filename, dataframe, **options)
    end
end
