lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "asciidoctor-adoc/version"

Gem::Specification.new do |s|
  s.authors = ['Pawel S. Veselov']
  s.files = Dir['lib/*.rb']
  s.name = 'asciidoctor-adoc'
  s.summary = 'Asciidoctor ADoc converter'
  s.version = AsciidoctorADoc::VERSION

  s.description = 'An Asciidoctor extension that generates ADoc output'
  s.email = ['pawel.veselov@gmail.com']
  s.homepage = 'https://github.com/veselov/asciidoctor-adoc'
  s.license = 'MIT'
  s.metadata = {
    "bug_tracker_uri" => "https://github.com/veselov/asciidoctor-adoc/issues",
    "homepage_uri" => s.homepage,
    "source_code_uri" => "https://github.com/veselov/asciidoctor-adoc/",
  }

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'bundler', '>= 2.2.18'
  s.add_development_dependency 'minitest', '~> 5'
  s.add_development_dependency 'rake', '~> 13'
  s.add_runtime_dependency 'asciidoctor', '>= 2.0.11', '< 2.1'
  s.date = '2021-07-09'
  s.required_ruby_version = '>= 2.5'
end
