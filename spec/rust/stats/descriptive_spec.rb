require 'spec_helper'

RSpec.describe Rust::Descriptive do
    describe '.mean' do
        it 'computes the mean' do
            expect(described_class.mean([1, 2, 3, 4, 5])).to eq(3.0)
        end

        it 'handles a single element' do
            expect(described_class.mean([7])).to eq(7.0)
        end

        it 'raises for non-numeric input' do
            expect { described_class.mean(['a', 'b']) }.to raise_error(TypeError)
        end
    end

    describe '.variance' do
        it 'computes the sample variance' do
            expect(described_class.variance([2, 4, 4, 4, 5, 5, 7, 9])).to be_within(1e-10).of(4.571428571428571)
        end

        it 'returns NaN for a single element' do
            expect(described_class.variance([1])).to be_nan
        end
    end

    describe '.standard_deviation' do
        it 'is the square root of variance' do
            data = [2, 4, 4, 4, 5, 5, 7, 9]
            expect(described_class.standard_deviation(data)).to be_within(1e-10).of(Math.sqrt(described_class.variance(data)))
        end

        it 'is aliased as sd and stddev' do
            data = [1, 2, 3]
            expect(described_class.sd(data)).to eq(described_class.standard_deviation(data))
            expect(described_class.stddev(data)).to eq(described_class.standard_deviation(data))
        end
    end

    describe '.median' do
        it 'returns the middle value for odd-length arrays' do
            expect(described_class.median([3, 1, 2])).to eq(2)
        end

        it 'returns the average of the two middle values for even-length arrays' do
            expect(described_class.median([1, 2, 3, 4])).to eq(2.5)
        end

        it 'returns NaN for empty array' do
            expect(described_class.median([])).to be_nan
        end
    end

    describe '.sum' do
        it 'sums the array' do
            expect(described_class.sum([1, 2, 3])).to eq(6)
        end
    end

    describe '.quantile' do
        let(:data) { [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] }

        it 'computes the min and max' do
            q = described_class.quantile(data, [0.0, 1.0])
            expect(q[0.0]).to eq(1)
            expect(q[1.0]).to eq(10)
        end

        it 'computes the median via quantile' do
            q = described_class.quantile(data, [0.5])
            expect(q[0.5]).to be_within(1e-10).of(5.5)
        end

        it 'raises for percentiles outside 0..1' do
            expect { described_class.quantile(data, [1.5]) }.to raise_error(RuntimeError)
        end
    end

    describe '.outliers' do
        it 'detects outliers using Tukey fences' do
            data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 100]
            expect(described_class.outliers(data)).to include(100)
        end

        it 'returns empty for clean data' do
            expect(described_class.outliers([1, 2, 3, 4, 5])).to be_empty
        end
    end
end
