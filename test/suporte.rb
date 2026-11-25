# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "plotline"

# Gera uma grade sintética de lotes, em metros, e a converte para GeoJSON
# no entorno de uma coordenada qualquer. Nada aqui vem de dado real.
module Suporte
  LAT0 = -16.70
  LNG0 = -49.25

  # `quadras` = [colunas, linhas] de quadras; cada quadra tem `lotes` colunas x fileiras.
  def self.grade(quadras: [2, 2], lotes: [4, 2], lote_m: [12.0, 30.0], rua_m: 14.0, giro: 0.0)
    larg_q = lotes[0] * lote_m[0]
    alt_q = lotes[1] * lote_m[1]
    feicoes = []
    n = 0
    quadras[1].times do |qy|
      quadras[0].times do |qx|
        n += 1
        lotes[1].times do |ly|
          lotes[0].times do |lx|
            x = (qx * (larg_q + rua_m)) + (lx * lote_m[0])
            y = (qy * (alt_q + rua_m)) + (ly * lote_m[1])
            quad = [[x, y], [x + lote_m[0], y], [x + lote_m[0], y + lote_m[1]], [x, y + lote_m[1]]]
            quad = Plotline::Geometria.girar(quad, giro)
            anel = quad.map { |px, py| proj.inverter(px, py) }
            anel << anel.first
            feicoes << {
              "type" => "Feature",
              "properties" => { "quadra" => n.to_s, "lote" => ((ly * lotes[0]) + lx + 1).to_s },
              "geometry" => { "type" => "Polygon", "coordinates" => [anel] }
            }
          end
        end
      end
    end
    JSON.generate("type" => "FeatureCollection", "features" => feicoes)
  end

  def self.proj = Plotline::Projecao.new(LAT0, LNG0)
end
