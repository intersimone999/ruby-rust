require 'code-assertions'
require 'stringio'
require 'rinruby'

##
# Basic module for the Rust package. It includes a series of sub-modules that provide specific features, such as
# statistical hypothesis tests, plots, and so on.

module Rust
    CLIENT_MUTEX = Mutex.new
    R_MUTEX      = Mutex.new
    
    R_ENGINE     = RinRuby.new(echo: false)
    
    private_constant    :R_ENGINE
    private_constant    :R_MUTEX
    private_constant    :CLIENT_MUTEX
    
    @@debugging = $RUST_DEBUG || false
    @@in_client_mutex = false
    
    ##
    # Sets the debug mode. Any call to R will be written on the standard output.
    
    def self.debug
        @@debugging = true
    end
    
    ##
    # Checks if the debug mode is active.
    
    def self.debug?
        return @@debugging
    end
    
    ##
    # Runs the given block with a mutex. It is mandatory to run any R command with this method. 
    
    def self.exclusive
        result = nil
        CLIENT_MUTEX.synchronize do
            @@in_client_mutex = true
            result = yield
            @@in_client_mutex = false
        end
        return result
    end
    
    ##
    # Sets a variable in the R environment with a given value.
    #
    # Raises an error if the value can not be translated into an R object.
    #
    # Example: Rust['a'] = 0.
    
    def self.[]=(variable, value)
        if value.is_a?(RustDatatype)
            value.load_in_r_as(variable.to_s)
        elsif value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(Array) || value.is_a?(::Matrix)
            R_ENGINE.assign(variable, value)
        else
            raise "Trying to assign #{variable} with #{value.class}; expected RustDatatype, String, Numeric, or Array"
        end
    end
    
    ##
    # Retrieves the value of a variable from the R environment.
    #
    # Example: Rust['a']
    
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
    
    ##
    # Checks if the given +name+ library can be used. Returns true if it is available, false otherwise.
    
    def self.check_library(name)
        self.exclusive do
            result, _ = self._pull("require(\"#{name}\", character.only = TRUE)", true)
            return result
        end
    end
    
    ##
    # Loads the given +name+ library.
    
    def self.load_library(name)
        self.exclusive do
            self._eval("library(\"#{name}\", character.only = TRUE)")
        end
        
        return nil
    end
    
    ##
    # Installs the given +name+ library and its dependencies.
    
    def self.install_library(name)
        self.exclusive do
            self._eval("install.packages(\"#{name}\", dependencies = TRUE)")
        end
        
        return nil
    end
    
    ##
    # Installs the +library+ library if it is not available and loads it.
    
    def self.prerequisite(library)
        self.install_library(library) unless self.check_library(library)
        self.load_library(library)
    end
    
    ##
    # Ask for help on a given +mod+.
    
    def self.help!(mod = nil)
        unless mod
            puts "You have the following modules:"
            Rust.constants.map { |c| Rust.const_get(c) }.select { |c| c.class == Module }.each do |mod|
                puts "\t- #{mod}"
            end
            puts "Run \"help! {module}\" for more detailed information about the module"
        else
            if mod.methods.include?(:help!)
                mod.help!
            else
                puts "Sorry, no help available for #{mod}"
            end
        end
    end
end

##
# Module that contains methods that allow to call R functions faster. Such methods have names resembling the ones
# available in R (e.g., cor, wilcox_test).

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

##
# Shortcut for including the RBinding module

def bind_r!
    include Rust::RBindings
end

bind_r! if ENV['RUBY_RUST_BINDING'] == '1'
