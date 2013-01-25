Gem::Specification.new do |s|
  s.name = 'awsome'
  s.version = '0.0.18'
  s.date = '2012-01-11'
  s.email = 'sebastian@foodocs.com'
  s.homepage = 'http://github.com/0x0539/awsome'
  s.description = 'AWS library targeted specifically for continuous integration.'
  s.summary = 'Intelligently plan automated, incremental deployments.'
  s.authors = ['Sebastian Goodman']
  s.files = Dir['lib/**/*.rb']
  s.executables << 'awsome'
  s.add_dependency('awesome_print')
  s.add_dependency('route53')
end
