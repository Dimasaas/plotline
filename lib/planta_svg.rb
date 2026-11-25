# frozen_string_literal: true

require_relative "planta_svg/version"

# Converte um GeoJSON de lotes em uma planta de loteamento em SVG.
module PlantaSvg
  # Erro de entrada (GeoJSON inválido, sem polígonos etc.).
  class Erro < StandardError; end
end
