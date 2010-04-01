begin
  require 'eventmachine'
rescue LoadError => e
  if require('rubygems') then retry
  else raise(e)
  end
end

module RakeServer
  class Client < EventMachine::Protocols::LineAndTextProtocol
    class <<self
      def run(tasks, options = {})
        options = DEFAULT_OPTIONS.merge(options)
        EventMachine.run do
          EventMachine.connect options[:host], options[:port], self, tasks
        end
      end
    end

    def initialize(tasks)
      super
      @tasks = tasks
    end

    def post_init
      send_data(@tasks.join(' ') + "\n")
    end

    def receive_data(data)
      if data =~ /\004$/
        super(data[0..-2]) if data.length > 1
        unbind
      else 
        super(data)
      end
    end

    def receive_line(data)
      puts(data)
    end

    def unbind
      EventMachine.stop_event_loop
    end
  end
end
