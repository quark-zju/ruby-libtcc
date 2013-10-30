Gem::Specification.new do |s|
  s.name = 'tcc'
  s.version = '0.1.0'
  s.summary = 'libtcc (library of Tiny C Compiler) wrapper.'
  s.description = 'Tiny C Compiler is a small and fast C compiler, which makes C behavor like a script language. This is the Ruby wrapper for its library, libtcc.'
  s.authors = ['Jun Wu', 'TinyCC develoeprs']
  s.email = 'quark@lihdd.net'
  s.homepage = 'https://github.com/quark-zju/ruby-libtcc'
  s.licenses = ['BSD', 'LGPL']
  s.require_paths = ['lib']
  s.files = %w[LICENSE README.md tcc.gemspec lib/tcc.rb ext/tcc/tcc-0.9.26.patch ext/tcc/extconf.rb]
  s.files += Dir.glob('ext/tcc/tcc-0.9.26/**/*')
  s.extensions = %w[ext/tcc/extconf.rb]
  s.add_dependency 'ffi', '~> 1.9.0'
end
