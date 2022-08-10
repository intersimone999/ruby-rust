require_relative '../rust'

module Rust
    
    ##
    # Represents a data-type that can be loaded from and written to R.
    
    class RustDatatype
        
        ##
        # Retrieves the given +variable+ from R and transforms it into the appropriate Ruby counterpart.
        # To infer the type, it uses the class method #can_pull? of all the RustDatatype classes to check the types
        # that are compatible with the given R variable (type and class). If more than a candidate is available, the one
        # with maximum #pull_priority is chosen.
        
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
        
        ##
        # Returns the priority of this type when a #pull_variable operation is performed. Higher priority means that
        # the type is to be preferred over other candidate types.
        
        def self.pull_priority
            0
        end
        
        ##
        # Writes the current object in R as +variable_name+.
        
        def load_in_r_as(variable_name)
            raise "Loading #{self.class} in R was not implemented"
        end
        
        ##
        # EXPERIMENTAL: Do not use
        
        def r_mirror_to(other_variable)
            varname = self.mirrored_R_variable_name
            
            Rust._eval("#{varname} = #{other_variable}")
            Rust["#{varname}.hash"] = self.r_hash
                        
            return varname
        end
        
        ##
        # EXPERIMENTAL: Do not use
        
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
        
        ##
        # Returns the hash of the current object.
        
        def r_hash
            self.hash.to_s
        end
        
        private
        def mirrored_R_variable_name
            return "rust.mirrored.#{self.object_id}"
        end
    end
    
    ##
    # The null value in R
    
    class Null < RustDatatype
        def self.can_pull?(type, klass)
            return type == "NULL" && klass == "NULL"
        end
        
        def self.pull_variable(variable, type, klass)
            return nil
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
    
    ##
    # Returns a string with the R representation of this object. Raises an exception for unsupported objects.
    
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
