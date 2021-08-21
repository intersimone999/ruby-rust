self_path = File.expand_path(__FILE__)
Dir.glob(File.dirname(self_path) + "/*.rb").each do |lib|
    require_relative lib unless lib == self_path
end
