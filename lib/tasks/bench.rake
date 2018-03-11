require 'derailed_benchmarks/tasks'
require 'benchmark_driver'

def bench(sizes)
end

task 'bench' => %w(perf:setup) do
  Benchmark.driver do |x|
    jit_opt = "--jit,--jit-min-calls=1"
    jit_opt << ",#{ENV["JITOPT"].gsub(" ", ",")}" if ENV["JITOPT"]
    x.rbenv *ENV["SIZES"].split(" ").map {|n| "system,#{jit_opt},--jit-max-cache=#{n}" }
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
