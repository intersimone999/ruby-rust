#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(__dir__, '..', 'lib'))
require 'rust/core'
require_relative 'fuzz_helper'
require 'tempfile'

module CsvFuzz
    include FuzzHelper

    ITERATIONS = get_fuzz_iterations()
    SEED       = get_fuzz_seed()

    CHARS = ('a'..'z').to_a + ('A'..'Z').to_a

    def self.random_string(len = rand(3..10))
        Array.new(len) { CHARS.sample }.join
    end

    def self.run
        passed = run_fuzz(ITERATIONS, SEED) do |i|
            n_rows       = rand(2..20)
            n_float_cols = rand(1..3)
            n_str_cols   = rand(1..2)

            cols = {}
            n_float_cols.times { |j| cols["f#{j}"] = Array.new(n_rows) { rand(-100.0..100.0).round(6) } }
            n_str_cols.times   { |j| cols["s#{j}"] = Array.new(n_rows) { random_string } }

            df  = Rust::DataFrame.new(cols)
            ctx = "rows=#{n_rows} floats=#{n_float_cols} strings=#{n_str_cols} i=#{i}"

            f    = Tempfile.new(['csv_fuzz', '.csv'])
            path = f.path
            f.close

            Rust::CSV.write(path, df)
            result = Rust::CSV.read(path, headers: true)
            File.unlink(path) rescue nil

            n_float_cols.times do |j|
                df.column("f#{j}").each_with_index do |v, k|
                    check("f#{j}[#{k}]", result.column("f#{j}")[k], v, ctx)
                end
            end

            n_str_cols.times do |j|
                df.column("s#{j}").each_with_index do |v, k|
                    check("s#{j}[#{k}]", result.column("s#{j}")[k], v, ctx)
                end
            end
        end

        exit(passed ? 0 : 1)
    end
end

CsvFuzz.run
