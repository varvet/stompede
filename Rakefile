require "bundler/gem_tasks"

task :console do
  exec "pry", "-rbundler/setup", "-rstompede"
end

namespace :ragel do
  task :generate do
    exec "ragel -R lib/stompede/stomp/parser.rl"
  end

  task :show do
    exec "ragel -V lib/stompede/stomp/parser.rl | dot -Tpng | open -a Preview -f"
  end
end

task :default do
  exec "rspec"
end
