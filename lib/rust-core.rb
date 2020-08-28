require 'stringio'
require 'rinruby'

module Rust
    CLIENT_MUTEX = Mutex.new
    R_MUTEX      = Mutex.new
    
    R_ENGINE     = RinRuby.new(echo: false)
    
    def self.exclusive
        CLIENT_MUTEX.synchronize do
            yield
        end
    end
    
    def self._pull(r_command, return_warnings = false)
        R_MUTEX.synchronize  do
            $stdout = StringIO.new
            R_ENGINE.echo(true, true)
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
            $stdout = StringIO.new
            R_ENGINE.echo(true, true)
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
