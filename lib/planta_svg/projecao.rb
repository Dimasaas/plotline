# frozen_string_literal: true

module PlantaSvg
  # Projeção equirretangular local: graus viram metros ao redor de um ponto de
  # referência. Um grau de latitude vale sempre o mesmo; um grau de longitude
  # encolhe com o cosseno da latitude, e é essa correção que mantém os lotes
  # com a proporção certa.
  class Projecao
    RAIO_TERRA_M = 6_371_008.8
    METROS_POR_GRAU = RAIO_TERRA_M * Math::PI / 180.0

    attr_reader :lat0, :lng0

    # Centra a projeção na caixa envolvente de uma lista de [lng, lat].
    def self.centrada_em(pontos)
      lngs = pontos.map(&:first)
      lats = pontos.map(&:last)
      new((lats.min + lats.max) / 2.0, (lngs.min + lngs.max) / 2.0)
    end

    def initialize(lat0, lng0)
      @lat0 = lat0.to_f
      @lng0 = lng0.to_f
      @metros_por_grau_lng = METROS_POR_GRAU * Math.cos(@lat0 * Math::PI / 180.0)
    end

    # [lng, lat] -> [x, y] em metros; x cresce para leste, y para norte.
    def projetar(lng, lat)
      [(lng - @lng0) * @metros_por_grau_lng, (lat - @lat0) * METROS_POR_GRAU]
    end

    # [x, y] em metros -> [lng, lat].
    def inverter(x, y)
      [(x / @metros_por_grau_lng) + @lng0, (y / METROS_POR_GRAU) + @lat0]
    end
  end
end
