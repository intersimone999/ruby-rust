require 'code-assertions'
require 'stringio'
require 'rinruby'

module Rust
    CLIENT_MUTEX = Mutex.new
    R_MUTEX      = Mutex.new
    
    R_ENGINE     = RinRuby.new(echo: false)
    
    @@in_client_mutex = false
    
    def self.exclusive
        CLIENT_MUTEX.synchronize do
            @@in_client_mutex = true
            yield
            @@in_client_mutex = false
        end
    end
    
    def self._pull(r_command, return_warnings = false)
        R_MUTEX.synchronize  do
            assert("This command must be executed in an exclusive block") { @@in_client_mutex }
            
            $stdout = StringIO.new
            if return_warnings
                R_ENGINE.echo(true, true)
            else
                R_ENGINE.echo(false, false)
            end
            result = R_ENGINE.pull(r_command)
            R_ENGINE.echo(false, false)
            warnings = $stdout.string
            $stdout = STDOUT
            
            if return_warnings
                return result, warnings.lines.map { |w| w.strip.chomp }
            else
                return result
            end
        end
    end
    
    def self._eval(r_command, return_warnings = false)
        R_MUTEX.synchronize do
            assert("This command must be executed in an exclusive block") { @@in_client_mutex }
            
            $stdout = StringIO.new
            if return_warnings
                R_ENGINE.echo(true, true)
            else
                R_ENGINE.echo(false, false)
            end
            result = R_ENGINE.eval(r_command)
            R_ENGINE.echo(false, false)
            warnings = $stdout.string
            $stdout = STDOUT
            
            if return_warnings
                return result, warnings.lines.map { |w| w.strip.chomp }
            else
                return result
            end
        end
    end
end
