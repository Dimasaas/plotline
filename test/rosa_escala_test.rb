# frozen_string_literal: true

require_relative "suporte"
require "rexml/document"

class RosaEscalaTest < Minitest::Test
  def doc(json, **o) = REXML::Document.new(Plotline.converter(json, **o))

  def rosa(d) = REXML::XPath.first(d, "//g[@id='rosa-dos-ventos']")

  def test_rosa_sem_giro_aponta_para_cima
    assert_match(/rotate\(-?0\.00 /, rosa(doc(Suporte.grade, giro: 0.0)).attributes["transform"])
  end

  def test_rosa_gira_ao_contrario_da_planta
    # planta girada 30 graus (anti-horário) => norte a 30 graus no sentido horário negativo
    t = rosa(doc(Suporte.grade, giro: 30.0)).attributes["transform"]
    assert_match(/rotate\(-30\.00 /, t)
  end

  def test_rosa_segue_o_giro_automatico
    d = doc(Suporte.grade(quadras: [3, 1], giro: 20.0))
    assert_match(/rotate\(20\.00 /, rosa(d).attributes["transform"])
  end

  def test_barra_de_escala_tem_valor_redondo_e_comprimento_proporcional
    # terreno de 172 m de largura: alvo 22% = 37,8 m -> barra de 20 m.
    json = Suporte.grade(quadras: [3, 1])
    d = doc(json, giro: 0.0, largura: 1060)
    rects = REXML::XPath.match(d, "//g[@id='escala']/rect")
    metade = rects.first.attributes["width"].to_f
    escala = 940.0 / 172.0 # unidades do SVG por metro
    assert_in_delta 10.0 * escala, metade, 0.5
    rotulos = REXML::XPath.match(d, "//g[@id='escala']/text").map(&:text)
    assert_equal ["0", "10", "20 m"], rotulos
  end
end
