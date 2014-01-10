require "bundler/gem_tasks"

rule ".rb" => ".rb.rl" do |t|
  sh "ragel", "-F1", "-R", t.source, "-o", t.name
end

namespace :ragel do
  desc "Build all ragel parsers"
  task :build => "lib/stompede/stomp/parser.rb"

  desc "Delete all ragel-generated parsers"
  task :clean do
    FileList["**/*.rl"].each do |file|
      rm_f file.sub(".rl", ".rb")
    end
  end

  desc "Show stomp parser state machine as an image"
  task :show => "lib/stompede/stomp/parser.rb" do |t|
    ragel = t.prerequisite_tasks[0]
    sh "ragel -V -p #{ragel.source} | dot -Tpng | open -a Preview -f"
  end
end

task :build => "ragel:build"

desc "Start a pry session with the gem loaded."
task :console => "ragel:build" do
  exec "pry", "-rbundler/setup", "-rstompede"
end

desc "Run the test suite."
task :spec => "ragel:build" do
  sh "rspec"
end

desc "Run the benchmarks."
task :bench => "ragel:build" do
  sh "ruby", "spec/bench_helper.rb"
end

task :default => :spec
