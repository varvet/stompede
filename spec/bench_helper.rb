require "bundler/setup"
require "stompede"
require "benchmark/ips"

$__benchmarks__ = []

def bench(name, *args, &block)
  file, line, _ = caller[0].split(':')
  $__benchmarks__ << {
    file: File.basename(file),
    line: line,
    name: name,
    block: proc { block.call(*args) }
  }
end

at_exit do
  reports = Benchmark.ips(time = 2) do |x|
    $__benchmarks__.each do |info|
      benchname = "#{info[:file]}:#{info[:line]} #{info[:name]}"
      raise "#{benchname} returned a non-truthy value" unless info[:block].call
      x.report(benchname, &info[:block])
    end
  end
end
