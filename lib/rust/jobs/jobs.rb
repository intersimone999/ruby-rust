require_relative '../core'

module Rust::Jobs
    class TaskHook
        def initialize(task, on_complete, on_error)
            @task = task
            @on_complete = on_complete
            @on_error = on_error
        end

        def complete!
            @on_complete.call
            @task.notify
        end

        def error!
            @on_error.call
            @task.notify
        end
    end

    class Task
        def initialize(title, &block)
            raise "Expected block to describe the task" unless block_given?
            @title = title
            @todo  = block
            @done  = false

            @complete_hook = proc {}
            @error_hook = proc {}
        end

        def start
            @thread = Thread.start do
                @todo.call(TaskHook.new(@complete_hook, @error_hook))
            end
        end

        def notify
            @done = true
        end

        def waitfor(granularity=0.1)
            while !@done
                sleep granularity
            end
        end

        def commit
        end

        def on_complete(&block)
            raise "Block expected" unless block_given?
            @complete_hook = block
        end

        def on_error(&block)
            raise "Block expected" unless block_given?
            @error_hook = block
        end
    end

    class Job
        def initialize(name, **options)
            @name = name
            @tasks = []

            @parallel = false

            if options['parallel']
                @parallel = true
                @parallel_tasks = 10
            end

            if options['parallel_tasks'].is_a?(Integer)
                @parallel_tasks = options['parallel_tasks'].to_i
            end

            @logger = options['logger'] ? options['logger'] : STDOUT

            if options[:quiet]
                @logger = File.open(File::NULL, "w")
            end
        end

        def log(message, type="INFO")
            @logger << "[#{type}] #{Time.now}: #{message.gsub("\n", " -- ")}"
        end

        def log_info(message)
            log(message, "INFO")
        end

        def log_warning(message)
            log(message, "WARNING")
        end

        def log_error(message)
            log(message, "ERROR")
        end

        def add_task(task=nil, **options, &block)
            if block_given?
                raise "You gave both a block and a task. Please, choose one" if task
                task = Task.new(options['title'], block)
            end

            raise "Expected a task, #{task.class} given instead" unless task.is_a?(Task)

            @tasks << task
        end

        def start
            log_info "Job \"#@name\" started"
            if @parallel
            else
                @tasks.each do |t|
                    t.on_complete do
                        log_info "Task \"#{t.title}\" completed"
                    end

                    t.on_error do |message|
                        log_error "Task \"#{t.title}\" did not complete: #{message}"
                    end

                    log_info "Task \"#{t.title}\" started"
                    t.start
                    t.waitfor
                end
            end
        end
    end

    class Resumeable < Job
        def initialize(name, **options)
            super
            # TODO complete here
        end

        def start
            # TODO complete here
        end
    end
end
