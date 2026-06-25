require 'rspec'

# Load only the pure-Ruby parts of rust, without starting R
require_relative '../lib/rust/core/types/datatype'
require_relative '../lib/rust/core/types/dataframe'
require_relative '../lib/rust/core/types/factor'
require_relative '../lib/rust/core/types/language'
require_relative '../lib/rust/core/types/utils'
require_relative '../lib/rust/core/csv'
require_relative '../lib/rust/stats/descriptive'

RSpec.configure do |config|
    config.formatter = :progress
end
