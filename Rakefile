require 'rake/testtask'

task :default => :test

task :test => [
   'test:test',
   'test:inline'
]

namespace :test do
   Rake::TestTask.new do |t|
      t.warning = false
      t.verbose = true
      t.test_files = FileList['test/*_test.rb']
   end

   Rake::TestTask.new(:inline) do |t|
      t.warning = false
      t.verbose = true
      # Different order won't work
      t.test_files = FileList[
         "lib/bitformat/inline",
         'test/*_test.rb',
         'test/inline_test_all.rb'
      ]
   end
end
