source 'https://rubygems.org'
gemspec

gem "rake"
gem "RubyInline", :platforms => [:ruby] if ENV['TRAVIS'] # optional

platform :rbx do
   gem "rubysl"
   gem "rubysl-test-unit"
end
