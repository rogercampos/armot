# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "armot/version"

Gem::Specification.new do |s|
  s.name        = "armot"
  s.version     = Armot::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Roger Campos"]
  s.email       = ["roger@itnig.net"]
  s.homepage    = "https://github.com/rogercampos/armot"
  s.summary     = %q{translation support for your models with an I18n active-record backend}
  s.description = %q{translation support for your models with an I18n active-record backend}

  s.rubyforge_project = "armot"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "i18n-active_record", ">= 0.0.2"
  s.add_development_dependency "activerecord", "~> 3.0.0"
  s.add_development_dependency "activesupport", "~> 3.0.0"
  s.add_development_dependency "rake"
  s.add_development_dependency "sqlite3"

end
