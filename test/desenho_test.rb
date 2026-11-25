# frozen_string_literal: true

require_relative "suporte"
require "rexml/document"

class DesenhoTest < Minitest::Test
  def svg(**o) = PlantaSvg.converter(Suporte.grade, **o)

  def test_svg_e_xml_valido_com_um_caminho_por_lote
    doc = REXML::Document.new(svg)
    assert_equal 32, REXML::XPath.match(doc, "//g[@id='lotes']/path").size
  end

  def test_usa_as_cores_e_o_degrade_pedidos
    s = svg
    assert_includes s, "#1a0b33"
    assert_includes s, "#0d1b4d"
    assert_includes s, "#00E5FF"
  end

  def test_respeita_a_largura_pedida
    assert_includes svg(largura: 900), 'viewBox="0 0 900 '
  end

  def test_proporcao_do_desenho_bate_com_a_do_terreno
    # grade 2x2 de quadras, 4x2 lotes de 12x30 m, rua de 14 m: 110 m x 134 m.
    h = svg(largura: 1000)[/viewBox="0 0 1000 (\d+)"/, 1].to_f
    assert_in_delta((880 * (134.0 / 110.0)) + 120, h, 2.0)
  end

  def test_sem_lotes_levanta_erro
    assert_raises(PlantaSvg::Erro) { PlantaSvg::Desenho.new([]) }
  end
end
