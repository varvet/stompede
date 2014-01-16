require "bundler/gem_tasks"

# Build state machine before building gem.
task :build => "ragel:build"

rule ".rb" => ".rb.rl" do |t|
  sh "ragel", "-F1", "-R", t.source, "-o", t.name
end

namespace :ragel do
  desc "Build all ragel parsers"
  task :build => "lib/stompede/stomp/parser.rb"

  desc "Remove all ragel-generated parsers"
  task :clean do |t|
    source_tasks = Rake::Task["build"].all_prerequisite_tasks.select(&:source)
    rm_f source_tasks.map(&:name)
  end

  desc "Show stomp parser state machine as an image"
  task :show => "lib/stompede/stomp/parser.rb" do |t|
    ragel = t.prerequisite_tasks[0]
    sh "ragel -V -p #{ragel.source} | dot -Tpng | open -a Preview -f"
  end
end

desc "Start a pry session with the gem loaded."
task :console => "ragel:build" do
  exec "pry", "-rbundler/setup", "-rstompede"
end

desc "Run the test suite."
task :spec => "ragel:build" do
  sh "rspec"
end

desc "Run all benchmarks."
task :bench => "ragel:build" do
  sh "ruby", "-I.", *FileList["spec/benchmarks/**/*.rb"].flat_map { |x| ["-r", x] }, "-e", "''"
end

desc "Run the profiler and show a gif, requires perftools.rb"
task :profile => "ragel:build" do
  # CPUPROFILE_METHODS=0 CPUPROFILE_OBJECTS=0 CPUPROFILE_REALTIME=1
  sh "CPUPROFILE_REALTIME=1 ruby spec/profile.rb"
  sh "pprof.rb --text spec/profile/parser.profile"
end

task :default => :spec
