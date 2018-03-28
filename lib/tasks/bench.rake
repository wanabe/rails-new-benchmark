require 'derailed_benchmarks/tasks'
require 'benchmark_driver'
require 'json'

module BenchmarkDriver
  class RubyInterface
    attr_reader :config
  end
end

task 'bench' => %w(perf:setup) do
  Benchmark.driver do |x|
    "#{ENV["BENCH_CONFIG"]}".scan(/([^,= ]*)=([^,= ]*)/) do |k, v|
      x.config[k] = JSON.parse(v)
    end
    if ENV["SIZES"]
      jit_opts = "max-cache=#{}"
    else
      jit_opts = ENV["JIT_OPTS"] || ""
    end
    rbenv_opts = jit_opts.split(" ").map do |opt|
      -"system".tap do |rbenv_opt|
        if opt != "none"
          rbenv_opt << ",--jit," << opt.split(",").map {|o| "--jit-#{o}" }.join(",")
        end
      end
    end
    x.rbenv *rbenv_opts
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
