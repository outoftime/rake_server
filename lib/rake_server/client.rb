begin
  require 'eventmachine'
rescue LoadError => e
  if require('rubygems') then retry
  else raise(e)
  end
end

module RakeServer
  class Client < EventMachine::Connection
    include EventMachine::Protocols::ObjectProtocol

    class <<self
      def run(args, options = {})
        options = DEFAULT_OPTIONS.merge(options)
        EventMachine.run do
          EventMachine.connect options[:host], options[:port], self, args
        end
      end
    end

    ENV_PATTERN = /^(\w+)=(.*)$/

    def initialize(args)
      begin
        super()
        @tasks, @env = [], {}
        args.each do |arg|
          if match = ENV_PATTERN.match(arg)
            @env[match[1]] = match[2]
          else
            @tasks << arg
          end
        end
      rescue => e
        STDERR.puts(e.inspect)
        STDERR.puts(e.backtrace)
      end
    end

    def post_init
      message = Message.new(@tasks, @env)
      send_object(message)
    end

    def receive_object(data)
      if data.nil?
        unbind
      else
        puts(data)
      end
    end

    def unbind
      EventMachine.stop_event_loop
    end
  end
end
