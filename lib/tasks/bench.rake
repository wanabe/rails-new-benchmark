ENV["RAILS_ENV"] = "production"
require 'derailed_benchmarks/tasks'
require 'benchmark_driver'
require 'json'

$bench_prelude = <<~'RUBY'
  ENV["RAILS_ENV"] = "production"
  ENV['SECRET_KEY_BASE'] = "test"

  require 'rubygems'
  require './config/boot'
  require 'rake'
  require 'bundler/setup'
  require './config/environment'

  @app = Rack::MockRequest.new(Rails.application)
  require './lib/bench'

  verbose = ENV["V"] == "1"
  training_num = ENV["TRAINING_NUM"]&.to_i
  if training_num
    c = training_num
    while c > 0
      c -= 1
      call_app
      STDERR.printf "%5d\r", c if verbose && c % 100 == 0
    end
    STDERR.puts if verbose
  end

  wait_sec = ENV["WAIT_SEC"]&.to_i
  if wait_sec
    c = wait_sec
    while c > 0
      c -= 1
      sleep 1
      STDERR.printf "%5d\r", c if verbose
    end
    STDERR.puts if verbose
    if RubyVM::MJIT.enabled?
      STDERR.puts "pause"
      RubyVM::MJIT.pause if RubyVM::MJIT.respond_to?(:pause)
    end
    sleep 3
  end

  if ENV["PERF_STAT"]
    $pid = Process.spawn("perf stat -e #{ENV["PERF_STAT"]} -p #{$$}")
    at_exit { Process.kill :INT, $pid }
  end

  if ENV["INTERACTIVE"] == "1"
    STDERR.puts "ready? #{$$} #{__FILE__}"
    STDIN.gets
  end
  GC.start
RUBY

module BenchmarkDriver::MyMixin
  def initialize(output: nil, runner: nil)
    super
    @teardown = ""
  end

  def run_duration(sec)
    @config.run_duration = sec
  end

  def rbenv_with_env(*versions)
    versions.each do |version_with_envs|
      version, *envs = version_with_envs.split(":")
      executable = BenchmarkDriver::Rbenv.parse_spec(version)
      prefix = %w(env)
      name = executable.name
      envs.each do |env|
        prefix << env
        name << ":" << env
      end
      executable.command = prefix + executable.command
      executable.name = name
      @executables << executable
    end
  end

  def run
    unless @executables.empty?
      @config.executables = @executables
    end

    jobs = @jobs.flat_map do |job|
      BenchmarkDriver::JobParser.parse(job_options.merge!(job))
    end
    BenchmarkDriver::Runner.run(jobs, config: @config)
  end

  def job_options
    {
      type: @config.runner_type,
      prelude: @prelude,
      loop_count: @loop_count,
      teardown: @teardown,
    }
  end

  def teardown(script)
    @teardown ||= ""
    @teardown << "#{script}\n"
  end
end

class BenchmarkDriver::RubyInterface
  include BenchmarkDriver::MyMixin
end

task 'bench' => %w(perf:setup) do
  Benchmark.driver do |x|
    x.rbenv_with_env *((ENV["RBENV"] || "system").split(" "))
    x.run_duration (ENV["DURATION"] || 5).to_i
    x.prelude $bench_prelude

    x.report 'bench', %{ call_app }
  end
end

task 'bench_raw' do
  eval $bench_prelude

  n = (ENV["N"] || 1000).to_i
  l = (ENV["L"] || 1).to_i
  j = 0
  while j < l
    j += 1
    t0 = Time.now
    i = 0
    while i < n
      i += 1
      call_app
    end
    t1 = Time.now

    i = 0
    while i < n
      i += 1
    end
    t2 = Time.now

    print n / (t1 - t0 - (t2 - t1)), " i/s\n"
    STDOUT.flush
  end
end
