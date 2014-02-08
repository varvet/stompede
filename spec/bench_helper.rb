require "bundler/setup"
require "stompede"
require "benchmark/ips"

class Benchpress
  attr_reader :options

  def initialize(options, &body)
    @options = options
    instance_exec(self, &body)
  end

  def name
    "#{options[:file]}:#{options[:line]} #{options[:desc]}"
  end

  def setup(&block)
    @setup = block
  end

  def code(&block)
    @code = block
  end

  def assert(&block)
    @assert = block
  end

  def run_initial
    instance_exec(&@setup) if @setup
    result = run
    result = instance_exec(result, &@assert) if @assert
    unless result
      raise "#{name} code returns #{result.inspect}"
    end
  end

  def run
    instance_exec(&@code)
  end

  def to_proc
    lambda { run }
  end
end

def describe(description, &body)
  file, line, _ = caller[0].split(':')
  options = {
    desc: description,
    file: File.basename(file),
    line: line,
  }

  $__benchmarks__ << Benchpress.new(options, &body)
end

$__benchmarks__ = []

at_exit do
  reports = Benchmark.ips(time = 2) do |x|
    $__benchmarks__.each do |bench|
      5.times { bench.run_initial }
      x.report(bench.name, &bench)
    end
  end
end
