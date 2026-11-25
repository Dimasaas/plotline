# frozen_string_literal: true

require "json"

module PlantaSvg
  # Um lote lido do GeoJSON: rótulos de quadra/lote e o anel externo em
  # [lng, lat], sem repetir o ponto de fechamento.
  Lote = Struct.new(:quadra, :lote, :anel, keyword_init: true)

  # Leitura tolerante de GeoJSON (FeatureCollection, Feature ou geometria solta).
  module Geojson
    CHAVES_QUADRA = %w[quadra qd nm_qdr].freeze
    CHAVES_LOTE = %w[lote lt nm_lot].freeze

    module_function

    def ler(texto)
      dados = JSON.parse(texto)
      lotes = []
      coletar(dados, lotes)
      raise Erro, "o GeoJSON não tem nenhum polígono" if lotes.empty?

      lotes
    rescue JSON::ParserError => e
      raise Erro, "GeoJSON inválido: #{e.message[0, 80]}"
    end

    def coletar(no, lotes)
      return unless no.is_a?(Hash)

      case no["type"]
      when "FeatureCollection" then Array(no["features"]).each { |f| coletar(f, lotes) }
      when "Feature" then geometria(no["geometry"], no["properties"] || {}, lotes)
      else geometria(no, {}, lotes)
      end
    end

    def geometria(geom, props, lotes)
      return unless geom.is_a?(Hash)

      aneis =
        case geom["type"]
        when "Polygon" then [geom["coordinates"]&.first]
        when "MultiPolygon" then Array(geom["coordinates"]).map(&:first)
        else []
        end

      aneis.each do |anel|
        pts = limpar(anel)
        next if pts.size < 3

        lotes << Lote.new(quadra: rotulo(props, CHAVES_QUADRA), lote: rotulo(props, CHAVES_LOTE), anel: pts)
      end
    end

    def limpar(anel)
      pts = Array(anel).map { |p| [Float(p[0]), Float(p[1])] }
      pts.pop if pts.size > 1 && pts.first == pts.last
      pts
    rescue ArgumentError, TypeError
      []
    end

    def rotulo(props, chaves)
      chave = chaves.find { |c| props[c].to_s.strip != "" }
      chave && props[chave].to_s.strip
    end
  end
end
