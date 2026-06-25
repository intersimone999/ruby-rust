module FuzzHelper
    BAR_WIDTH = 40

    def self.included(base)
        base.instance_variable_set(:@failures, [])
        base.instance_variable_set(:@passes,   0)
        base.instance_variable_set(:@total,    0)
        base.extend(ClassMethods)
    end

    module ClassMethods
        def failures; @failures; end
        def passes;   @passes;   end
        def total;    @total;    end

        def check(name, ruby_val, r_val, context, tol = 1e-9)
            @total += 1
            if near?(ruby_val, r_val, tol)
                @passes += 1
            else
                @failures << "#{name}: ruby=#{ruby_val.inspect}  r=#{r_val.inspect}  |  #{context}"
            end
        end

        def near?(a, b, tol = 1e-9)
            return true if a == b
            if a.respond_to?(:nan?) && b.respond_to?(:nan?)
                return true if a.nan? && b.nan?
            end
            return false unless a.is_a?(Numeric) && b.is_a?(Numeric)
            (a - b).abs <= tol
        end

        def quiet?
            ARGV.include?('--quiet')
        end

        def get_fuzz_iterations(iterations = 500)
            idx = ARGV.index('--iter')
            idx ? ARGV[idx + 1].to_i : iterations
        end

        def get_fuzz_seed(seed = Random.new_seed)
            idx = ARGV.index('--seed')
            idx ? ARGV[idx + 1].to_i : seed
        end

        def draw_progress(done, total)
            return if quiet?
            filled  = (BAR_WIDTH * done / total.to_f).round
            bar     = "\e[32m#{'█' * filled}\e[0m#{'░' * (BAR_WIDTH - filled)}"
            pct     = (100.0 * done / total).round(1)
            pass_s  = "\e[32m✔ #{@passes}\e[0m"
            fail_s  = @failures.empty? ? "\e[32m✘ 0\e[0m" : "\e[31m✘ #{@failures.size}\e[0m"
            print "\r  [#{bar}] #{pct}%  (#{done}/#{total})  #{pass_s}  #{fail_s}   "
            $stdout.flush
        end

        def run_fuzz(iterations, seed, &block)
            srand(seed)
            puts "\e[1mFuzz seed:\e[0m #{seed}   \e[1mIterations:\e[0m #{iterations}"
            puts unless quiet?

            iterations.times do |i|
                block.call(i)
                draw_progress(i + 1, iterations)
            end

            puts unless quiet?
            if @failures.empty?
                puts "\e[32m✔ All #{@total} checks passed.\e[0m"
                true
            else
                puts "\e[31m✘ #{@failures.size} failure(s) out of #{@total} checks:\e[0m"
                @failures.each { |f| puts "    #{f}" }
                false
            end
        end
    end
end
