require 'rake'
require 'rspec/core/rake_task'

GEMSPEC = "rust.gemspec"

RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/**/*_spec.rb'
end

task :fuzz do
    Dir.glob('fuzz/**/*_fuzz.rb').each do |script|
        puts "Running #{script}..."
        system(RbConfig.ruby, script) || abort("Fuzz test failed: #{script}")
    end
end

task default: :spec

task :release, [:version] do |_, args|
  version = args[:version]
  abort "Usage: rake release[VERSION]" unless version
  abort "Invalid version format (expected e.g. 0.14)" unless version =~ /^\d+\.\d+(\.\d+)*$/

  current = File.read(GEMSPEC)[/s\.version\s*=\s*'([^']+)'/, 1]
  abort "Version #{version} is already set in #{GEMSPEC}" if current == version

  today = Time.now.strftime("%Y-%m-%d")

  # Update gemspec
  content = File.read(GEMSPEC)
  content = content.gsub(/s\.version\s*=\s*'[^']+'/, "s.version     = '#{version}'")
  content = content.gsub(/s\.date\s*=\s*'[^']+'/,    "s.date        = '#{today}'")
  File.write(GEMSPEC, content)

  sh "git add #{GEMSPEC}"
  sh "git commit -m 'Release #{version}'"
  sh "git tag v#{version}"
  sh "git push origin master"
  sh "git push origin v#{version}"

  gemfile = "rust-#{version}.gem"
  sh "gem build #{GEMSPEC}"
  sh "gem push #{gemfile}"
end
