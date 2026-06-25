require 'spec_helper'
require 'tempfile'

RSpec.describe Rust::CSV do
    let(:df) do
        Rust::DataFrame.new({'name' => ['Alice', 'Bob', 'Carol'], 'score' => [10, 20, 30], 'ratio' => [1.1, 2.2, 3.3]})
    end

    def with_tempfile(content = nil)
        f = Tempfile.new(['rust_csv_spec', '.csv'])
        f.write(content) if content
        f.flush
        yield f.path
    ensure
        f.close
        f.unlink
    end

    describe '.write / .read roundtrip' do
        it 'preserves string columns' do
            with_tempfile do |path|
                Rust::CSV.write(path, df)
                result = Rust::CSV.read(path, headers: true)
                expect(result.column('name')).to eq(['Alice', 'Bob', 'Carol'])
            end
        end

        it 'infers integer columns by default' do
            with_tempfile do |path|
                Rust::CSV.write(path, df)
                result = Rust::CSV.read(path, headers: true)
                expect(result.column('score')).to eq([10, 20, 30])
                expect(result.column('score').first).to be_a(Float)
            end
        end

        it 'infers integers separately when infer_integers is true' do
            with_tempfile do |path|
                Rust::CSV.write(path, df)
                result = Rust::CSV.read(path, headers: true, infer_integers: true)
                expect(result.column('score').first).to be_a(Integer)
                expect(result.column('ratio').first).to be_a(Float)
            end
        end

        it 'preserves float columns' do
            with_tempfile do |path|
                Rust::CSV.write(path, df)
                result = Rust::CSV.read(path, headers: true)
                expect(result.column('ratio')).to eq([1.1, 2.2, 3.3])
            end
        end

        it 'preserves column names' do
            with_tempfile do |path|
                Rust::CSV.write(path, df)
                result = Rust::CSV.read(path, headers: true)
                expect(result.column_names).to eq(['name', 'score', 'ratio'])
            end
        end

        it 'preserves row count' do
            with_tempfile do |path|
                Rust::CSV.write(path, df)
                result = Rust::CSV.read(path, headers: true)
                expect(result.rows).to eq(3)
            end
        end
    end

    describe '.read' do
        it 'reads a CSV without headers, generating X1..Xn column names' do
            with_tempfile("1,2,3\n4,5,6\n") do |path|
                result = Rust::CSV.read(path)
                expect(result.column_names).to eq(['X1', 'X2', 'X3'])
                expect(result.rows).to eq(2)
            end
        end

        it 'skips number inference when infer_numbers is false' do
            with_tempfile do |path|
                Rust::CSV.write(path, df)
                result = Rust::CSV.read(path, headers: true, infer_numbers: false)
                expect(result.column('score').first).to be_a(String)
            end
        end
    end

    describe '.write' do
        it 'raises for non-DataFrame input' do
            expect { Rust::CSV.write('/tmp/x.csv', [1, 2, 3]) }.to raise_error(TypeError)
        end

        it 'writes no header when headers: false' do
            with_tempfile do |path|
                Rust::CSV.write(path, df, headers: false)
                lines = File.readlines(path)
                expect(lines.first.strip).to eq('Alice,10,1.1')
            end
        end
    end

    describe '.read_all' do
        it 'reads all CSVs matching a glob pattern' do
            Dir.mktmpdir do |dir|
                Rust::CSV.write("#{dir}/a.csv", df)
                Rust::CSV.write("#{dir}/b.csv", df)
                result = Rust::CSV.read_all("#{dir}/*.csv", headers: true)
                expect(result.size).to eq(2)
                expect(result.values.first).to be_a(Rust::DataFrame)
            end
        end
    end
end
