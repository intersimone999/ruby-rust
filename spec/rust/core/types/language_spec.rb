require 'spec_helper'

RSpec.describe Rust::Formula do
    describe '#initialize' do
        it 'stores left and right parts' do
            f = Rust::Formula.new('y', 'x1 + x2')
            expect(f.left_part).to eq('y')
            expect(f.right_part).to eq('x1 + x2')
        end

        it 'accepts nil left part' do
            f = Rust::Formula.new(nil, 'x')
            expect(f.left_part).to eq('')
        end

        it 'raises for non-string left part' do
            expect { Rust::Formula.new(42, 'x') }.to raise_error(ArgumentError)
        end

        it 'raises for non-string right part' do
            expect { Rust::Formula.new('y', 42) }.to raise_error(ArgumentError)
        end
    end

    describe '#to_R' do
        it 'generates correct R formula string' do
            expect(Rust::Formula.new('y', 'x').to_R).to eq('y ~ x')
        end

        it 'handles nil left part' do
            expect(Rust::Formula.new(nil, 'x').to_R).to eq(' ~ x')
        end
    end

    describe '#==' do
        it 'equals a formula with same parts' do
            expect(Rust::Formula.new('y', 'x')).to eq(Rust::Formula.new('y', 'x'))
        end

        it 'does not equal a formula with different parts' do
            expect(Rust::Formula.new('y', 'x')).not_to eq(Rust::Formula.new('y', 'z'))
        end
    end
end

RSpec.describe Rust::Options do
    describe '#to_R' do
        it 'generates key=value pairs' do
            opts = Rust::Options.new
            opts['col'] = 'red'
            opts['lwd'] = 2
            expect(opts.to_R).to eq('col="red", lwd=2')
        end
    end

    describe '.from_hash' do
        it 'creates Options from a hash' do
            opts = Rust::Options.from_hash(width: 6, height: 4)
            expect(opts['width']).to eq(6)
            expect(opts['height']).to eq(4)
        end
    end
end

RSpec.describe Rust::Arguments do
    describe '#to_R' do
        it 'joins arguments as R expressions' do
            args = Rust::Arguments.new
            args << [1, 2, 3]
            args << 'hello'
            expect(args.to_R).to eq('c(1,2,3), "hello"')
        end
    end
end

RSpec.describe 'to_R extensions' do
    it 'converts nil to NULL' do
        expect(nil.to_R).to eq('NULL')
    end

    it 'converts true to TRUE' do
        expect(true.to_R).to eq('TRUE')
    end

    it 'converts false to FALSE' do
        expect(false.to_R).to eq('FALSE')
    end

    it 'converts integers' do
        expect(42.to_R).to eq('42')
    end

    it 'converts floats' do
        expect(3.14.to_R).to eq('3.14')
    end

    it 'converts NaN float to NA' do
        expect(Float::NAN.to_R).to eq('NA')
    end

    it 'converts strings with quotes' do
        expect('hello'.to_R).to eq('"hello"')
    end

    it 'converts symbols with quotes' do
        expect(:foo.to_R).to eq('"foo"')
    end

    it 'converts arrays to R vectors' do
        expect([1, 2, 3].to_R).to eq('c(1,2,3)')
    end

    it 'raises for unsupported types' do
        expect { Object.new.to_R }.to raise_error(TypeError)
    end
end
