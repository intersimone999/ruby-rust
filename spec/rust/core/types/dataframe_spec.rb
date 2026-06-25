require 'spec_helper'

RSpec.describe Rust::DataFrame do
    let(:df) do
        Rust::DataFrame.new({'a' => [1, 2, 3], 'b' => ['x', 'y', 'z']})
    end

    describe '#initialize' do
        it 'creates an empty dataframe from column names' do
            d = Rust::DataFrame.new(['a', 'b'])
            expect(d.rows).to eq(0)
            expect(d.column_names).to eq(['a', 'b'])
        end

        it 'creates a populated dataframe from a hash' do
            expect(df.rows).to eq(3)
            expect(df.column_names).to eq(['a', 'b'])
        end
    end

    describe '#column / #|' do
        it 'returns the column array' do
            expect(df.column('a')).to eq([1, 2, 3])
        end

        it 'supports the | alias' do
            expect(df | 'b').to eq(['x', 'y', 'z'])
        end

        it 'returns nil for unknown columns' do
            expect(df.column('z')).to be_nil
        end
    end

    describe '#row' do
        it 'returns the row as a hash' do
            expect(df.row(0)).to eq({'a' => 1, 'b' => 'x'})
        end

        it 'returns nil for out-of-bounds index' do
            expect(df.row(99)).to be_nil
            expect(df.row(-1)).to be_nil
        end
    end

    describe '#fast_row' do
        it 'returns the row as an array' do
            expect(df.fast_row(1)).to eq([2, 'y'])
        end
    end

    describe '#add_row / #<<' do
        it 'appends a row from an array' do
            df << [4, 'w']
            expect(df.rows).to eq(4)
            expect(df.row(3)).to eq({'a' => 4, 'b' => 'w'})
        end

        it 'appends a row from a hash' do
            df << {'a' => 4, 'b' => 'w'}
            expect(df.rows).to eq(4)
        end

        it 'raises for wrong array size' do
            expect { df << [1] }.to raise_error(RuntimeError)
        end

        it 'raises for wrong hash keys' do
            expect { df << {'a' => 1, 'c' => 2} }.to raise_error(RuntimeError)
        end
    end

    describe '#add_column' do
        it 'adds a column from an array' do
            df.add_column('c', [7, 8, 9])
            expect(df.column('c')).to eq([7, 8, 9])
        end

        it 'adds a column from a block' do
            df.add_column('c') { |row| row['a'] * 2 }
            expect(df.column('c')).to eq([2, 4, 6])
        end

        it 'raises if column already exists' do
            expect { df.add_column('a', [1, 2, 3]) }.to raise_error(RuntimeError)
        end

        it 'raises if size does not match' do
            expect { df.add_column('c', [1, 2]) }.to raise_error(RuntimeError)
        end
    end

    describe '#rename_column!' do
        it 'renames a column' do
            df.rename_column!('a', 'aa')
            expect(df.column_names).to include('aa')
            expect(df.column_names).not_to include('a')
            expect(df.column('aa')).to eq([1, 2, 3])
        end

        it 'raises for unknown column' do
            expect { df.rename_column!('z', 'zz') }.to raise_error(RuntimeError)
        end

        it 'raises if new name already exists' do
            expect { df.rename_column!('a', 'b') }.to raise_error(RuntimeError)
        end
    end

    describe '#transform_column!' do
        it 'applies a function to each value in a column' do
            df.transform_column!('a') { |v| v * 10 }
            expect(df.column('a')).to eq([10, 20, 30])
        end
    end

    describe '#select_rows' do
        it 'returns a filtered dataframe' do
            result = df.select_rows { |r| r['a'] > 1 }
            expect(result.rows).to eq(2)
            expect(result.column('a')).to eq([2, 3])
        end
    end

    describe '#select_columns' do
        it 'returns a dataframe with only the specified columns' do
            result = df.select_columns(['a'])
            expect(result.column_names).to eq(['a'])
            expect(result.column('b')).to be_nil
        end

        it 'supports a block' do
            result = df.select_columns { |name| name == 'b' }
            expect(result.column_names).to eq(['b'])
        end
    end

    describe '#delete_column' do
        it 'removes a column' do
            df.delete_column('a')
            expect(df.column_names).to eq(['b'])
        end
    end

    describe '#delete_row' do
        it 'removes a row by index' do
            df.delete_row(1)
            expect(df.rows).to eq(2)
            expect(df.column('a')).to eq([1, 3])
        end
    end

    describe '#sort_by / #sort_by!' do
        let(:unsorted) { Rust::DataFrame.new({'n' => [3, 1, 2], 'l' => ['c', 'a', 'b']}) }

        it 'returns a sorted copy' do
            result = unsorted.sort_by('n')
            expect(result.column('n')).to eq([1, 2, 3])
            expect(result.column('l')).to eq(['a', 'b', 'c'])
            expect(unsorted.column('n')).to eq([3, 1, 2])
        end

        it 'sorts in place' do
            unsorted.sort_by!('n')
            expect(unsorted.column('n')).to eq([1, 2, 3])
        end

        it 'raises for unknown column' do
            expect { unsorted.sort_by!('z') }.to raise_error(ArgumentError)
        end
    end

    describe '#uniq_by / #uniq_by!' do
        let(:duped) { Rust::DataFrame.new({'k' => [1, 2, 1, 3], 'v' => ['a', 'b', 'c', 'd']}) }

        it 'returns a deduplicated copy' do
            result = duped.uniq_by(['k'])
            expect(result.column('k')).to eq([1, 2, 3])
            expect(duped.rows).to eq(4)
        end
    end

    describe '#merge' do
        let(:left)  { Rust::DataFrame.new({'id' => [1, 2, 3], 'val' => ['a', 'b', 'c']}) }
        let(:right) { Rust::DataFrame.new({'id' => [2, 3, 4], 'num' => [20, 30, 40]}) }

        it 'performs an inner join' do
            result = left.merge(right, ['id'], 'l', 'r')
            expect(result.rows).to eq(2)
            expect(result.column('id')).to eq([2, 3])
            expect(result.column('l.val')).to eq(['b', 'c'])
            expect(result.column('r.num')).to eq([20, 30])
        end

        it 'performs a right join' do
            result = left.right_merge(right, ['id'], 'l', 'r')
            expect(result.rows).to eq(3)
            expect(result.column('id')).to include(4)
        end
    end

    describe '#bind_rows / #rbind' do
        it 'appends rows from another dataframe' do
            other = Rust::DataFrame.new({'a' => [4, 5], 'b' => ['p', 'q']})
            result = df.bind_rows(other)
            expect(result.rows).to eq(5)
            expect(result.column('a')).to eq([1, 2, 3, 4, 5])
        end
    end

    describe '#bind_columns / #cbind' do
        it 'appends columns from another dataframe' do
            other = Rust::DataFrame.new({'c' => [7, 8, 9]})
            result = df.bind_columns(other)
            expect(result.column_names).to include('c')
            expect(result.column('c')).to eq([7, 8, 9])
        end
    end

    describe '#aggregate' do
        let(:grouped) { Rust::DataFrame.new({'g' => ['a', 'a', 'b', 'b'], 'v' => [1, 3, 2, 4]}) }

        it 'aggregates by group' do
            result = grouped.aggregate('g') { |vals| vals.sum }
            expect(result.rows).to eq(2)
            sums = result.column('g').zip(result.column('v')).to_h
            expect(sums['a']).to eq(4)
            expect(sums['b']).to eq(6)
        end
    end

    describe '#head' do
        it 'returns the first n rows' do
            result = df.head(2)
            expect(result.rows).to eq(2)
            expect(result.column('a')).to eq([1, 2])
        end
    end

    describe '#clone' do
        it 'returns an independent copy' do
            copy = df.clone
            copy.transform_column!('a') { |v| v * 100 }
            expect(df.column('a')).to eq([1, 2, 3])
        end
    end

    describe '#each / #each_with_index' do
        it 'iterates rows as hashes' do
            keys = []
            df.each { |r| keys << r['a'] }
            expect(keys).to eq([1, 2, 3])
        end

        it 'provides row index' do
            indices = []
            df.each_with_index { |_, i| indices << i }
            expect(indices).to eq([0, 1, 2])
        end
    end

    describe '#[]' do
        it 'selects rows by range' do
            result = df[1..2]
            expect(result.rows).to eq(2)
            expect(result.column('a')).to eq([2, 3])
        end

        it 'selects columns by array' do
            result = df[nil, ['a']]
            expect(result.column_names).to eq(['a'])
        end
    end

    describe 'DataFrameArray#bind_all' do
        it 'concatenates all dataframes' do
            arr = Rust::DataFrameArray.new
            arr << Rust::DataFrame.new({'x' => [1, 2]})
            arr << Rust::DataFrame.new({'x' => [3, 4]})
            result = arr.bind_all
            expect(result.column('x')).to eq([1, 2, 3, 4])
        end
    end
end
