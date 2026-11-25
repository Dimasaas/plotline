# frozen_string_literal: true

require_relative "lib/plotline/version"

Gem::Specification.new do |s|
  s.name        = "plotline"
  s.version     = Plotline::VERSION
  s.authors     = ["João Victor Diamantino Cardoso"]
  s.email       = ["80987512+Dimasaas@users.noreply.github.com"]
  s.summary     = "GeoJSON de lotes em planta de loteamento SVG, só com a stdlib do Ruby."
  s.description = "Projeta lotes em metros, escolhe a rotação que deixa a planta deitada, " \
                  "põe rótulos, barra de escala e rosa dos ventos e devolve um SVG."
  s.homepage    = "https://github.com/Dimasaas/plotline"
  s.license     = "PolyForm-Noncommercial-1.0.0"
  s.required_ruby_version = ">= 3.2"

  s.files       = Dir["lib/**/*.rb", "bin/*", "LICENSE", "README.md"]
  s.bindir      = "bin"
  s.executables = %w[plotline plotline-goiania]
  s.metadata["source_code_uri"] = s.homepage
end
