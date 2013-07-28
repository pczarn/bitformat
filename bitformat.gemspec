$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

Gem::Specification.new 'bitformat', '0.1' do |s|
   s.description = 'BitFormat is a Ruby DSL for simple, extensible and fast binary structures.'
   s.summary     = 'DSL for binary data and serialization'
   s.homepage    = "https://github.com/pczarn/bitformat"
   s.email       = "pioczarn@gmail.com"
   s.author      = "Piotr Czarnecki"

   s.rdoc_options     = %w[--line-numbers --inline-source --title BitFormat --main README.md --encoding=UTF-8]
   s.extra_rdoc_files = %w[README.md]

   s.files        = Dir['lib/**/*', 'README.md']
   s.require_path = 'lib'
end
