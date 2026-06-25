#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(__dir__, '..', 'lib'))
require 'rust/core/types/datatype'
require 'rust/core/types/factor'
require_relative 'fuzz_helper'

module FactorFuzz
    include FuzzHelper

    ITERATIONS = get_fuzz_iterations()
    SEED       = get_fuzz_seed()

    def self.run
        passed = run_fuzz(ITERATIONS, SEED) do |i|
            n_levels = rand(2..8)
            levels   = n_levels.times.map { |j| :"lv#{j}" }
            n_values = rand(5..30)
            indices  = Array.new(n_values) { rand(1..n_levels) }

            factor = Rust::Factor.new(indices.dup, levels)
            ctx    = "n_levels=#{n_levels} n=#{n_values} i=#{i}"

            indices.each_with_index do |idx, pos|
                fv = factor[pos]
                check("val[#{pos}]",   fv.value, idx,             ctx)
                check("level[#{pos}]", fv.level, levels[idx - 1], ctx)
            end

            new_idx = rand(1..n_levels)
            factor[0] = new_idx
            check("set_int value", factor[0].value, new_idx,             ctx)
            check("set_int level", factor[0].level, levels[new_idx - 1], ctx)

            new_sym = levels.sample
            factor[0] = new_sym
            check("set_sym value", factor[0].value, levels.index(new_sym) + 1, ctx)
            check("set_sym level", factor[0].level, new_sym,                   ctx)
        end

        exit(passed ? 0 : 1)
    end
end

FactorFuzz.run
