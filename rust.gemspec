Gem::Specification.new do |s|
  s.name        = 'rust'
  s.version     = '0.7'
  s.date        = '2021-02-16'
  s.summary     = "Ruby advanced statistical library"
  s.description = "Ruby advanced statistical library based on RinRuby"
  s.authors     = ["Simone Scalabrino"]
  s.email       = 's.scalabrino9@gmail.com'
  s.files       = Dir.glob("lib/**/*.rb")
  s.homepage    = 'https://github.com/intersimone999/ruby-rust'
  s.license     = "GPL-3.0-only"
  
  s.add_runtime_dependency "rinruby"        , "~> 2.1.0", ">= 2.1.0"
  s.add_runtime_dependency "code-assertions", "~> 1.1.2", ">= 1.1.2"
end
