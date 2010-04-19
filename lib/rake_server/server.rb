begin
  require 'eventmachine'
  require 'rake'
rescue LoadError => e
  if require('rubygems') then retry
  else raise(e)
  end
end

module RakeServer
  class Server < EventMachine::Connection
    include EventMachine::Protocols::ObjectProtocol

    class <<self
      def start(eager_tasks, options = {})
        pid_file = File.join(pid_dir(options), "rake-server.pid")
        read, write = IO.pipe
        tmp_pid = fork do
          read.close
          fork do
            Process.setsid
            run(eager_tasks, options) do
              write.write(Process.pid.to_s)
              write.close
              STDOUT.reopen('/dev/null')
              STDERR.reopen(STDOUT)
            end
          end
          write.close
        end
        write.close
        pid = read.read.to_i
        File.open(pid_file, 'w') { |f| f << pid }
        read.close
        Process.waitpid(tmp_pid)
      end

      def stop(options = {})
        if File.exist?(pid_file = File.join(pid_dir(options), "rake-server.pid"))
          pid = IO.read(pid_file).to_i
          begin
            Process.kill("TERM", pid)
          rescue Errno::ESRCH
            STDERR.puts("No rake-server process running at PID #{pid}")
            # No worries
          end
          FileUtils.rm(pid_file)
        else
          STDERR.puts("No PIDfile at #{pid_file}")
        end
      end

      def run(eager_tasks, options = {}, &block)
        options = DEFAULT_OPTIONS.merge(options)
        EventMachine.run do
          Rake.application.init
          Rake.application.load_rakefile
          eager_tasks.each { |task| Rake.application[task].invoke }
          EventMachine.start_server(options[:host], options[:port], self)
          unless options[:quiet]
            puts "rake-server listening on #{options[:host]}:#{options[:port]}"
          end
          block.call if block
        end
      end

      def before_fork(&block)
        @before_fork = block
      end

      def after_fork(&block)
        @after_fork = block
      end

      def run_before_fork
        @before_fork.call if @before_fork
      end

      def run_after_fork
        @after_fork.call if @after_fork
      end

      private

      def pid_dir(options)
        pid_dir = options[:pid_dir] || File.join(Dir.pwd, 'tmp', 'pids')
        unless File.directory?(pid_dir)
          raise "PID dir #{pid_dir} does not exist -- can't daemonize"
        end
        pid_dir
      end
    end

    def receive_object(message)
      begin
        tasks = message.tasks.map { |task| Rake.application[task.to_sym] }
        pid = fork_and_run_tasks(tasks, message.env || {})
      rescue => e
        send_object("ERR #{e.message}\n")
        send_object(nil)
      end
    end

    private

    def fork_and_run_tasks(tasks, env)
      input, output = IO.pipe
      self.class.run_before_fork
      pid = fork do
        self.class.run_after_fork
        env.each_pair do |key, value|
          ENV[key] = value
        end
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
                send_object(data) 
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
        send_object(input.read) until input.eof?
        send_object(nil)
      end
    end
  end
end
