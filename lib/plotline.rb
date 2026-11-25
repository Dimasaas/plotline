# frozen_string_literal: true

require_relative "plotline/version"

# Converte um GeoJSON de lotes em uma planta de loteamento em SVG.
module Plotline
  # Erro de entrada (GeoJSON inválido, sem polígonos etc.).
  class Erro < StandardError; end

  # Atalho: texto GeoJSON -> texto SVG.
  def self.converter(geojson, **opcoes)
    Desenho.new(Geojson.ler(geojson), **opcoes).para_svg
  end
end

require_relative "plotline/geojson"
require_relative "plotline/rotacao"
require_relative "plotline/escala"
require_relative "plotline/desenho"
