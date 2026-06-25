require_relative '../core'
require 'time'

module Rust
    
    ##
    # Class that allows to read CSVs exported from Google Forms.
    class GoogleFormMapping

        ##
        # Loads a mapping from a CSV file that can be used in the constructor of GoogleForm given the CSV +filename+ and the
        # keys for defining what should be transformed (+key_from+) in what (+key_to+). Returns a hash with the mapping
        # from -> to.

        def self.load(filename, key_from="from", key_to="to", **options)
            raise TypeError, "Expected string for filename" unless filename.is_a?(String)
            raise TypeError, "Expected string for key_from" unless key_from.is_a?(String)
            raise TypeError, "Expected string for key_to" unless key_to.is_a?(String)

            result = {}
            mapping = Rust::CSV.read(filename, headers: true)
            mapping.each do |r|
                result[r[key_from]] = r[key_to]
            end

            return GoogleFormMapping.new(result, **options)
        end

        def initialize(hash, **options)
            raise TypeError, "Hash should be an hash" unless hash.is_a?(Hash)
            raise TypeError, "Mapping for question #{question} must have either all String keys or all Regexp keys." if !hash.keys.all? { |m| m.is_a?(Regexp) } && !hash.keys.all? { |m| m.is_a?(String) }
            raise "Unsupported options: #{options.keys - [:strip, :downcase]}" if (options.keys - [:strip, :downcase]).size > 0

            if hash.keys.all? { |m| m.is_a?(Regexp) }
                @type = :regexp
            else
                @type = :direct
            end

            @strip = options[:strip]
            @downcase = options[:downcase]

            if @type == :direct
                @hash = {}
                hash.each do |k, v|
                    @hash[normalize(k)] = v
                end
            else
                @hash = hash
            end
        end

        def get(from)
            if @type == :regexp
                @hash.each do |k, v|
                    if from.match(k)
                        return v
                    end
                end
                return from
            elsif @type == :direct
                return @hash[normalize(from)] || from
            end
        end

        private
        def normalize(string)
            string = string.downcase if @downcase
            string = string.strip    if @strip
            return string
        end
    end
    
    class GoogleForm
        ALLOWED_TYPES = [:multiple, :checkbox, :scale, :text]

        ##
        # Reads the CSV at +filename+ and returns a GoogleForm. The schema must be a hash that contains, for each question number or name,
        # the type of answer (:multiple, :checkbox, :scale, or :text). For the other options, see Rust::CSV.read.
        
        def self.read(filename, schema, mappings={}, **options)
            data_frame = Rust::CSV.read(filename, **options)

            return GoogleForm.new(data_frame, schema, mappings)
        end
        
        def initialize(data_frame, schema, mappings={})
            raise TypeError, "Expected Rust::DataFrame" unless data_frame.is_a?(Rust::DataFrame)
            raise TypeError, "Expected Hash or Array" if !schema.is_a?(Hash) && !schema.is_a?(Array)
            raise TypeError, "Schema keys must all be numbers or strings" if schema.is_a?(Hash) && !schema.keys.all? { |k| k.is_a?(String) }
            raise TypeError, "Mappings should be an hash [String, Integer] -> GoogleFormMapping" if !mappings.is_a?(Hash) || !mappings.keys.all? { |k| k.is_a?(String) || k.is_a?(Integer) } || !mappings.values.all? { |v| v.is_a?(GoogleFormMapping) }
            if schema.is_a?(Array)
                new_schema = {}
                for i in 0...schema.size
                    new_schema[index_to_title(i+1, data_frame)] = schema[i]
                end
                schema = new_schema
            end
            raise TypeError, "Schema values must all be #{ALLOWED_TYPES}; #{schema.values.uniq - ALLOWED_TYPES} given instead" if !schema.values.all? { |v| ALLOWED_TYPES.include?(v)}
            raise TypeError, "Schema must include types for all the questions" if schema.size != (data_frame.columns - 1)

            @data_frame = data_frame
            @questions  = data_frame.colnames
            @schema = schema

            mappings.each do |question, mapping|
                raise "Mappings can not be defined for :scale questions" if schema[title_to_index(question)] == :scale
            end
            @mappings = mappings
        end

        def data_frame
            @data_frame
        end

        def mapped_data_frame
            df = Rust::DataFrame.new(@data_frame.colnames)
            self.each_answer do |a|
                df << a
            end
            return df
        end

        def rows
            @data_frame.rows
        end

        def answer(i)
            row = @data_frame.row(i)

            @questions.each_with_index do |colname, i|
                if i == 0
                    row[colname] = Time.parse(row[colname])
                else
                    row[colname] = get_value(row[colname], colname)
                end
            end

            return row
        end

        def each_answer
            for i in 0...@data_frame.rows
                yield(self.answer(i))
            end
        end

        def answers
            answers = []
            for i in 0...@data_frame.rows
                answers << self.answer(i)
            end
            return answers
        end

        def filter
            matching = Rust::DataFrame.new(@questions)

            for i in 0...@data_frame.rows
                matching << @data_frame.row(i) if yield(self.answer(i))
            end

            return GoogleForm.new(matching, @schema, @mappings)
        end

        def raw_answers_to(question)
            question = index_to_title(question) if question.is_a?(Integer)
            results = []

            (@data_frame|question).each do |value|
                value = get_value(value, question)
                results << value
            end

            return results
        end

        def answers_to(question)
            question = index_to_title(question) if question.is_a?(Integer)

            results = {}

            (@data_frame|question).each do |value|
                value = get_value(value, question)
                if value.is_a?(Array)
                    value.each do |v|
                        results[v] = 0 unless results[v]
                        results[v] += 1
                    end
                else
                    results[value] = 0 unless results[value]
                    results[value] += 1
                end
            end
            results.delete(nil)

            return results
        end

        def textual_answers_to(question)
            question = index_to_title(question) if question.is_a?(Integer)
            raise TypeError, "Expected textual question, #{@schema[question]} instead" if @schema[question] != :text

            results = {}

            (@data_frame|question).each do |value|
                value = get_value(value, question)
                next if value == nil

                category = yield(value)
                results[category] = 0 unless results[category]
                results[category] += 1
            end

            return results
        end

        def percentual_answers_to(question, exclude=[])
            answers = answers_to(question)

            exclude.each do |ex|
                answers.delete(ex)
            end

            tot = answers.values.sum
            answers = answers.map { |k, v| [k, v.to_f/tot] }.to_h
            return answers
        end

        def percentual_textual_answers_to(question, &block)
            answers = textual_answers_to(question, &block)

            tot = answers.values.sum
            answers = answers.map { |k, v| [k, v.to_f/tot] }.to_h
            return answers
        end

        private
        def index_to_title(i, data_frame=@data_frame)
            data_frame.colnames[i]
        end

        def title_to_index(title, data_frame=@data_frame)
            data_frame.colnames.index(title)
        end

        def get_value(value, question, data_frame=@data_frame)
            mapping = @mappings[question]

            mapped_value = mapping ? mapping.get(value) : value

            case @schema[question]
            when :multiple
                return nil if mapped_value == ""
                return mapped_value

            when :checkbox
                return value.split(';').map { |single_value| mapping ? mapping.get(single_value) : single_value }

            when :scale
                return nil if value == ""
                ordinal = (data_frame|question).uniq.sort
                ordinal.delete("")
                return ordinal.index(value) + 1

            when :text
                return mapped_value
            end

            raise TypeError
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
