require "bundler/gem_tasks"

desc "Start a pry session with the gem loaded."
task :console do
  exec "pry", "-rbundler/setup", "-rstompede"
end

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

task :default => :spec
