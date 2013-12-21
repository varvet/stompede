require "bundler/setup"
require "stompede"
require "benchmark"
require "pry"

$__benchmarks__ = []

def bench(name, iterations = 10_000, &block)
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
      raise "#{benchname} returned a non-truthy value" unless info[:block].call
      x.report(benchname) { info[:iterations].times(&info[:block]) }
    end
  end

  width = reports.map { |r| r.label.length }.max + 3
  puts
  puts "Results ".ljust(width, "-")
  reports.zip($__benchmarks__).each do |report, bench|
    speed = "#{(bench[:iterations] / report.total).round(2)} / s"
    padding = " " * (width - report.label.length)
    puts report.label + padding + speed
  end
  puts "".ljust(width, "-")
end

Dir["./**/*_bench.rb"].each do |benchmark|
  require benchmark
end
