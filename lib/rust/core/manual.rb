require_relative 'rust'

module Rust
    class Manual
        @@manuals = {}
        
        def self.about
            puts "Manuals available:"
            @@manuals.each do |category, manual|
                puts "\t- #{manual.name} (:#{category}) → #{manual.description}"
            end
            
            return nil
        end
        
        def self.for(category)
            category = category.to_sym
            raise "No manual found for '#{category}'." unless @@manuals[category]
            
            return @@manuals[category]
        end
        
        def self.register(category, name, description)
            category = category.to_sym
            
            @@manuals[category] = Manual.new(name, description)
            
            return nil
        end
        
        attr_reader     :name
        attr_reader     :description
        
        def initialize(name, description)            
            @name = name
            @description = description
            @voices = {}
        end
        
        def lookup(query)
            @voices.each do |key, value|
                if query.match(key[1])
                    puts "*** #{key[0]} ***"
                    puts value
                    return
                end
            end
            
            puts "Voice not found"
            
            return nil
        end
        
        def n_voices
            @voices.size
        end
        
        def about
            puts "****** Manual for #@name ******"
            puts @description
            puts "Voices in manual #@name:"
            @voices.keys.each do |key, matcher|
                puts "\t- #{key}"
            end
            
            return nil
        end
        
        def register(voice, matcher, description)
            @voices[[voice, matcher]] = description
        end
        
        def inspect
            return "Manual for #@name with #{self.n_voices} voices"
        end
    end
end

module Rust::RBindings
    def rust_help(category = nil, query = nil)
        if !category
            return Rust::Manual.about
        elsif !query
            return Rust::Manual.for(category).about
        else
            return Rust::Manual.for(category).lookup(query)
        end
    end
end
