# frozen_string_literal: true

require_relative "suporte"
require "rexml/document"

class RotulosTest < Minitest::Test
  def doc(json = Suporte.grade, **o) = REXML::Document.new(Plotline.converter(json, **o))

  def textos(d, grupo) = REXML::XPath.match(d, "//g[@id='#{grupo}']/text")

  def test_rotulo_de_quadra_para_cada_quadra
    assert_equal %w[Q1 Q2 Q3 Q4], textos(doc, "rotulos-quadras").map(&:text).sort
  end

  def test_rotulos_de_lote_existem_e_trazem_numeros
    lotes = textos(doc, "rotulos-lotes").map(&:text)
    assert_operator lotes.size, :>, 10
    assert(lotes.all? { |t| t.match?(/\A\d+\z/) })
  end

  def test_sem_rotulos
    d = doc(rotulos: false)
    assert_empty textos(d, "rotulos-lotes")
    assert_empty textos(d, "rotulos-quadras")
  end

  def test_texto_do_lote_fica_no_centroide
    d = doc(giro: 0.0)
    lote1 = textos(d, "rotulos-lotes").find { |t| t.text == "1" }
    x = lote1.attributes["x"].to_f
    y = lote1.attributes["y"].to_f
    caminho = REXML::XPath.match(d, "//g[@id='lotes']/path").first.attributes["d"]
    pts = caminho.delete("MZ").split("L").map { |p| p.split.map(&:to_f) }
    assert_in_delta(pts.sum { |p| p[0] } / 4, x, 0.2)
    assert_in_delta(pts.sum { |p| p[1] } / 4, y, 0.2)
  end

  def test_texto_rotulo_e_escapado
    json = JSON.parse(Suporte.grade)
    json["features"][0]["properties"]["lote"] = "<A&B>"
    svg = Plotline.converter(JSON.generate(json))
    assert_includes svg, "&lt;A&amp;B&gt;"
    REXML::Document.new(svg) # continua XML válido
  end

  def test_rotulo_de_quadra_acompanha_o_angulo_da_quadra
    d = doc(Suporte.grade(quadras: [1, 1], lotes: [6, 1], giro: 0.0), giro: 0.0)
    q = textos(d, "rotulos-quadras").first
    assert_nil q.attributes["transform"] # quadra deitada: texto sem giro
  end

  def test_quadra_inclinada_gera_texto_inclinado_quando_nao_se_gira_a_planta
    d = doc(Suporte.grade(quadras: [1, 1], lotes: [6, 1], giro: 25.0), giro: 0.0)
    transform = textos(d, "rotulos-quadras").first.attributes["transform"]
    assert_match(/rotate\(-?25\.0 /, transform)
  end

  def test_quadra_com_letra_nao_ganha_prefixo_q
    json = JSON.parse(Suporte.grade(quadras: [1, 1]))
    json["features"].each { |f| f["properties"]["quadra"] = "F47" }
    d = doc(JSON.generate(json))
    assert_equal ["F47"], textos(d, "rotulos-quadras").map(&:text)
  end
end
