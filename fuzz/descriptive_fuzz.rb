#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(__dir__, '..', 'lib'))
require 'rust/core'
require 'rust/stats/descriptive'
require_relative 'fuzz_helper'

module DescriptiveFuzz
    include FuzzHelper

    ITERATIONS = (ENV['FUZZ_ITER'] || 500).to_i
    SEED       = (ENV['FUZZ_SEED'] || Random.new_seed).to_i

    def self.run
        passed = run_fuzz(ITERATIONS, SEED) do |i|
            size = rand(2..80)
            data = Array.new(size) { rand(-1000.0..1000.0).round(6) }
            Rust.exclusive { Rust['fuzz.data'] = data }

            ctx = "n=#{size} i=#{i}"

            check("mean",     Rust::Descriptive.mean(data),               Rust.exclusive { Rust._pull("mean(fuzz.data)")   }, ctx)
            check("variance", Rust::Descriptive.variance(data),           Rust.exclusive { Rust._pull("var(fuzz.data)")    }, ctx)
            check("sd",       Rust::Descriptive.standard_deviation(data), Rust.exclusive { Rust._pull("sd(fuzz.data)")     }, ctx)
            check("median",   Rust::Descriptive.median(data),             Rust.exclusive { Rust._pull("median(fuzz.data)") }, ctx)

            percentiles = [0.0, 0.25, 0.5, 0.75, 1.0]
            ruby_q = Rust::Descriptive.quantile(data, percentiles)
            r_q    = Rust.exclusive { Rust._pull("quantile(fuzz.data, type=7)") }
            percentiles.each_with_index do |p, qi|
                check("quantile(#{p})", ruby_q[p], r_q[qi], ctx)
            end
        end

        exit(passed ? 0 : 1)
    end
end

DescriptiveFuzz.run
