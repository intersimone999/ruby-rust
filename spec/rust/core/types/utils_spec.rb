require 'spec_helper'

RSpec.describe Rust::MathArray do
    let(:a) { Rust::MathArray.new([1, 2, 3]) }
    let(:b) { Rust::MathArray.new([4, 5, 6]) }

    describe '#-' do
        it 'subtracts elementwise' do
            expect(b - a).to eq([3, 3, 3])
        end

        it 'subtracts a scalar' do
            expect(a - 1).to eq([0, 1, 2])
        end
    end

    describe '#+' do
        it 'adds elementwise' do
            expect(a + b).to eq([5, 7, 9])
        end

        it 'adds a scalar' do
            expect(a + 10).to eq([11, 12, 13])
        end
    end

    describe '#*' do
        it 'multiplies elementwise' do
            expect(a * b).to eq([4, 10, 18])
        end

        it 'multiplies by a scalar' do
            expect(a * 3).to eq([3, 6, 9])
        end
    end

    describe '#/' do
        it 'divides elementwise' do
            expect(b / a).to eq([4, 2, 2])
        end

        it 'divides by a scalar' do
            expect(b / 2).to eq([2, 2, 3])
        end
    end

    describe '#**' do
        it 'raises each element to a power' do
            expect(a ** 2).to eq([1, 4, 9])
        end
    end

    describe 'error handling' do
        it 'raises for size mismatch' do
            expect { a + Rust::MathArray.new([1, 2]) }.to raise_error(ArgumentError)
        end

        it 'raises for non-numeric scalar in **' do
            expect { a ** 'x' }.to raise_error(ArgumentError)
        end
    end
end
