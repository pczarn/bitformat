source 'https://rubygems.org'
gemspec

gem "rake"

# optional
gem "RubyInline", :platforms => [:ruby, :rbx] if ENV['TRAVIS']

platform :rbx do
   gem "rubysl"
   gem "rubysl-test-unit"
end
