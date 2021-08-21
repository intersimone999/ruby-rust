require_relative 'core/rust'
require_relative 'core/csv'

self_path = File.expand_path(__FILE__)
Dir.glob(File.join(File.dirname(self_path), "core/types/*.rb")).each do |lib|
    require_relative lib
end
