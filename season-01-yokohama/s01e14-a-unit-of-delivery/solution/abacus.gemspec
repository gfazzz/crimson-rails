# frozen_string_literal: true

require_relative "lib/abacus"

Gem::Specification.new do |spec|
  spec.name = "abacus"
  spec.version = Abacus::VERSION
  spec.authors = ["Расчётная палата железных дорог"]
  spec.email = ["clearing@seymour-street.example"]

  spec.summary = "Счётная библиотека железнодорожных ведомостей"
  spec.description = "Ведомости, отчёты, тарифы, реестр дорог и разбор " \
                     "присланных данных: то, что нужно конторе для сведения " \
                     "сквозных перевозок."
  spec.homepage = "https://github.com/gfazzz/crimson-rails"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  # Dir, а не git ls-files: гем должен собираться и там, где нет git.
  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "rubygems_mfa_required" => "true"
  }
end
