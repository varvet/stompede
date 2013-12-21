require "bundler/gem_tasks"

# Generate Ragel parser on gem build; always.
task :build => "ragel:generate"

task :console do
  exec "pry", "-rbundler/setup", "-rstompede"
end

namespace :ragel do
  task :generate do
    sh "ragel -R lib/stompede/stomp.rl"
  end

  task :show do
    sh "ragel -V -p lib/stompede/stomp.rl | dot -Tpng | open -a Preview -f"
  end
end

task :default do
  sh "rspec"
end
