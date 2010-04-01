begin
  require 'eventmachine'
  require 'rake'
rescue LoadError => e
  if require('rubygems') then retry
  else raise(e)
  end
end

module RakeServer
  class Server < EventMachine::Protocols::LineAndTextProtocol
    class <<self
      def run(eager_tasks, options = {})
        options = DEFAULT_OPTIONS.merge(options)
        EventMachine.run do
          Rake.application.init
          Rake.application.load_rakefile
          eager_tasks.each { |task| Rake.application[task].invoke }
          EventMachine.start_server(options[:host], options[:port], self)
        end
      end
    end

    def receive_data(data)
      if data == "\004"
        close_connection
        return
      else
        super(data)
      end
    end

    def receive_line(data)
      begin
        pid = fork_and_run_tasks(
            data.split(/\s+/).map { |task| Rake.application[task.to_sym] })
      rescue => e
        send_data("ERR #{e.message}\n")
      end
    end

    private

    def fork_and_run_tasks(tasks)
      input, output = IO.pipe
      pid = fork do
        input.close
        STDOUT.reopen(output)
        STDERR.reopen(output)
        begin
          tasks.each { |task| task.invoke }
        rescue => e
          STDERR.puts(e.message)
          STDERR.puts(e.backtrace)
        ensure
          output.close
        end
      end
      output.close
      monitor_tasks(pid, input)
    end

    def monitor_tasks(pid, input)
      EventMachine.defer(monitor(pid, input), done(input))
    end

    def monitor(pid, input)
      proc do
        begin
          until Process.waitpid(pid, Process::WNOHANG)
            begin
              until input.eof? || (data = input.read_nonblock(4096)).empty?
                send_data(data) 
              end
            rescue Errno::EAGAIN
            end
          end
          sleep(0.1)
        rescue => e
          STDERR.puts(e.inspect)
        end
      end
    end

    def done(input)
      lambda do
        send_data(input.read) until input.eof?
        send_data("\004")
      end
    end
  end
end
