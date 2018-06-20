require 'derailed_benchmarks/tasks'
require 'benchmark_driver'
require 'json'

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
        name << "," << env
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
    x.prelude <<~'RUBY'
      ENV['SECRET_KEY_BASE'] = "test"
      require './config/boot'
      require 'rake'
      require 'bundler/setup'
      require './config/environment'

      @app = Rack::MockRequest.new(Rails.application)
      def call_app
        response = @app.get("/", {})
        raise "Bad request: #{ response.body }" unless response.status == 200
        response
      end

      GC.start
      GC.disable
    RUBY

    x.report 'bench', %{ call_app }
  end
end
