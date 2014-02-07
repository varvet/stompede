require "rake/extensiontask"
require "bundler/gem_tasks"

def ragel(*args)
  sh "ragel", "-I.", *args
end

# Build state machine before building gem.
task :build => :compile

file "parser_common.rl"

rule ".rb" => %w[.rb.rl parser_common.rl] do |t|
  ragel "-F1", "-R", t.source, "-o", t.name
end

rule ".c" => %w[.c.rl parser_common.rl] do |t|
  ragel "-F1", "-C", t.source, "-o", t.name
end

desc "ragel machines"
task :compile => %w[lib/stompede/stomp/ruby_parser.rb]

unless RUBY_ENGINE == "jruby"
  task :compile => %w[ext/stompede/c_parser.c]

  Rake::ExtensionTask.new do |ext|
    ext.name = "c_parser"
    ext.ext_dir = "ext/stompede"
    ext.lib_dir = "lib/stompede/stomp"
  end
end

desc "ragel machines"
task :clean do |t|
  source_tasks = Rake::Task[:compile].prerequisite_tasks.grep(Rake::FileTask)
  rm_f source_tasks.map(&:name)
end

namespace :ragel do
  desc "Show stomp parser state machine as an image"
  task :show => "lib/stompede/stomp/ruby_parser.rb" do |t|
    mkdir_p "tmp"
    ragel "-V", "-p", t.prerequisite_tasks[0].source, "-o", "tmp/parser.dot"
    sh "dot -Tpng -O tmp/parser.dot"
    rm "tmp/parser.dot"
    sh "open tmp/parser.dot.png"
    rm "tmp/parser.dot.png"
  end
end

desc "Start a pry session with the gem loaded."
task :console => :compile do
  exec "pry", "-rbundler/setup", "-rstompede"
end

desc "Run the test suite."
task :spec => :compile do
  sh "rspec"
end

desc "Run all benchmarks."
task :bench => :compile do
  sh "ruby", "-I.", *FileList["spec/benchmarks/**/*.rb"].flat_map { |x| ["-r", x] }, "-e", "''"
end

desc "Run the profiler and show a gif, requires perftools.rb"
task :profile => :compile do
  # CPUPROFILE_METHODS=0 CPUPROFILE_OBJECTS=0 CPUPROFILE_REALTIME=1
  sh "CPUPROFILE_REALTIME=1 ruby spec/profile.rb"
  sh "pprof.rb --text spec/profile/parser.profile"
end

task :default => :spec
