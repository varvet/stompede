require "bundler/setup"
require "stompede"
require "benchmark"
require "pry"

$__benchmarks__ = []

def bench(name, iterations = 100_000, &block)
  file, line, _ = caller[0].split(':')
  $__benchmarks__ << {
    file: File.basename(file),
    line: line,
    name: name,
    iterations: iterations,
    block: block
  }
end

at_exit do
  reports = Benchmark.bmbm do |x|
    $__benchmarks__.each do |info|
      benchname = "#{info[:file]}:#{info[:line]} #{info[:name]} (x#{info[:iterations]})"
      x.report(benchname) { info[:iterations].times(&info[:block]) }
    end
  end

  puts
  puts "Results ".ljust(86, "-")
  reports.zip($__benchmarks__).each do |report, bench|
    puts "#{report.label}: #{(bench[:iterations] / report.total).round(2)} / s"
  end
  puts "".ljust(86, "-")
end

Dir["./**/*_bench.rb"].each do |benchmark|
  require benchmark
end
