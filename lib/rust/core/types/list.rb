require_relative 'datatype'

module Rust
    
    ##
    # Mirror of the list type in R.
    
    class List < RustDatatype
        def self.can_pull?(type, klass)
            return type == "list"
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
        
        ##
        # Creates an empty list of a given class (+klass+) and the specified +names+.
        
        def initialize(klass, names = [])
            @data = {}
            @names = names
            @klass = klass
        end
        
        ##
        # Returns the elements for the name +key+.
        
        def [](key)
            key = get_key(key)
            
            return @data[key]
        end
        alias :| :[]
        
        ##
        # Sets the +value+ for name +key+.
        
        def []=(key, value)
            key = get_key(key)
            
            return @data[key] = value
        end
        
        ##
        # Returns the names of the list.
        
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
end
