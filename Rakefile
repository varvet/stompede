require "bundler/gem_tasks"

rule ".rb" => [".rl"] do |t|
  sh "ragel", "-R", t.source, "-o", t.name
end

namespace :ragel do
  desc "Build all ragel parsers"
  task :build => "lib/stompede/stomp/parser.rb"

  desc "Show stomp parser state machine as an image"
  task :show do
    sh "ragel -V -p lib/stompede/stomp/parser.rl | dot -Tpng | open -a Preview -f"
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

task :default => :spec
