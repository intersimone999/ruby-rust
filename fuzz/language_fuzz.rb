#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(__dir__, '..', 'lib'))
require 'rust/core'
require_relative 'fuzz_helper'

module LanguageFuzz
    include FuzzHelper

    ITERATIONS = get_fuzz_iterations()
    SEED       = get_fuzz_seed()

    CHARS = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + [' ', '_']

    def self.random_safe_string(len = rand(2..12))
        Array.new(len) { CHARS.sample }.join
    end

    def self.run
        passed = run_fuzz(ITERATIONS, SEED) do |i|
            ctx = "i=#{i}"

            n   = rand(-1_000_000..1_000_000)
            r_n = Rust.exclusive { Rust._pull(n.to_R) }
            check("integer", r_n, n.to_f, ctx)

            f   = rand(-1000.0..1000.0).round(8)
            r_f = Rust.exclusive { Rust._pull(f.to_R) }
            check("float", r_f, f, ctx)

            s   = random_safe_string
            r_s = Rust.exclusive { Rust._pull(s.to_R) }
            check("string", r_s, s, ctx)

            r_true  = Rust.exclusive { Rust._pull(true.to_R) }
            r_false = Rust.exclusive { Rust._pull(false.to_R) }
            check("true",  r_true,  true,  ctx)
            check("false", r_false, false, ctx)

            arr   = Array.new(rand(2..10)) { rand(-100.0..100.0).round(6) }
            r_arr = Rust.exclusive { Rust._pull(arr.to_R) }
            arr.each_with_index do |v, k|
                check("arr[#{k}]", r_arr[k], v, ctx)
            end
        end

        exit(passed ? 0 : 1)
    end
end

LanguageFuzz.run
