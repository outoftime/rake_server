module RakeServer
  autoload :Server, File.join(File.dirname(__FILE__), 'rake_server', 'server')
  autoload :Client, File.join(File.dirname(__FILE__), 'rake_server', 'client')

  DEFAULT_OPTIONS = {
    :host => '127.0.0.1',
    :port => 7253
  }
  Message = Struct.new(:tasks, :env)
end
