# frozen_string_literal: true

require_relative "planta_svg/version"

# Converte um GeoJSON de lotes em uma planta de loteamento em SVG.
module PlantaSvg
  # Erro de entrada (GeoJSON inválido, sem polígonos etc.).
  class Erro < StandardError; end

  # Atalho: texto GeoJSON -> texto SVG.
  def self.converter(geojson, **opcoes)
    Desenho.new(Geojson.ler(geojson), **opcoes).para_svg
  end
end

require_relative "planta_svg/geojson"
require_relative "planta_svg/rotacao"
require_relative "planta_svg/escala"
require_relative "planta_svg/desenho"
