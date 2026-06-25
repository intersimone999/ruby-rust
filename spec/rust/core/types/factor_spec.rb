require 'spec_helper'

RSpec.describe Rust::Factor do
    let(:factor) { Rust::Factor.new([1, 2, 1, 3], [:a, :b, :c]) }

    describe '#initialize' do
        it 'stores levels as symbols' do
            expect(factor.levels).to eq([:a, :b, :c])
        end
    end

    describe '#[]' do
        it 'returns a FactorValue with correct value and level' do
            fv = factor[0]
            expect(fv.value).to eq(1)
            expect(fv.level).to eq(:a)
        end

        it 'returns the correct level for each index' do
            expect(factor[1].level).to eq(:b)
            expect(factor[2].level).to eq(:a)
            expect(factor[3].level).to eq(:c)
        end
    end

    describe '#[]=' do
        it 'sets by integer index' do
            factor[0] = 2
            expect(factor[0].level).to eq(:b)
        end

        it 'sets by symbol' do
            factor[0] = :c
            expect(factor[0].level).to eq(:c)
        end

        it 'raises for out-of-bounds integer' do
            expect { factor[0] = 99 }.to raise_error(RuntimeError)
        end

        it 'raises for unknown symbol' do
            expect { factor[0] = :z }.to raise_error(RuntimeError)
        end
    end

    describe '#to_a' do
        it 'returns an array of FactorValues' do
            arr = factor.to_a
            expect(arr.size).to eq(4)
            expect(arr.map(&:level)).to eq([:a, :b, :a, :c])
        end
    end

    describe '#==' do
        it 'is equal to a factor with the same values and levels' do
            other = Rust::Factor.new([1, 2, 1, 3], [:a, :b, :c])
            expect(factor).to eq(other)
        end

        it 'is not equal with different values' do
            other = Rust::Factor.new([1, 1, 1, 3], [:a, :b, :c])
            expect(factor).not_to eq(other)
        end
    end
end

RSpec.describe Rust::FactorValue do
    let(:fv) { Rust::FactorValue.new(2, :b) }

    describe '#to_i' do
        it 'returns the numeric value' do
            expect(fv.to_i).to eq(2)
        end
    end

    describe '#to_sym' do
        it 'returns the level' do
            expect(fv.to_sym).to eq(:b)
        end
    end

    describe '#==' do
        it 'equals another FactorValue with same value and level' do
            expect(fv).to eq(Rust::FactorValue.new(2, :b))
        end

        it 'equals an integer matching the value' do
            expect(fv).to eq(2)
        end

        it 'equals a symbol matching the level' do
            expect(fv).to eq(:b)
        end
    end
end
