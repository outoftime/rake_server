begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "rake_server"
    gemspec.summary = "Run rake tasks in a client-server architecture"
    gemspec.description = <<DESC
RakeServer is a library which allows Rake tasks to be run using client requests
to a long-running rake server, which can eagerly load required code into memory
for fast task invocation.
DESC
    gemspec.email = "mat@patch.com"
    gemspec.homepage = "http://github.com/outoftime/rake_server"
    gemspec.authors = ['Mat Brown', 'Cedric Howe']
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  STDERR.puts("Jeweler not available. Install it with `gem install jeweler'")
end
