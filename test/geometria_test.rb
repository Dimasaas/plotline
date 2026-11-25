# frozen_string_literal: true

require_relative "suporte"

class GeometriaTest < Minitest::Test
  G = PlantaSvg::Geometria
  RETANGULO = [[0, 0], [10, 0], [10, 4], [0, 4]].freeze

  def test_area_e_centroide_do_retangulo
    assert_in_delta 40.0, G.area(RETANGULO), 1e-9
    assert_equal [5.0, 2.0], G.centroide(RETANGULO)
  end

  def test_centroide_de_l_nao_e_o_centro_da_caixa
    l = [[0, 0], [4, 0], [4, 1], [1, 1], [1, 4], [0, 4]]
    cx, cy = G.centroide(l)
    assert_in_delta cx, cy, 1e-9
    assert_operator cx, :<, 2.0
  end

  def test_area_nula_cai_na_media
    assert_equal [1.0, 1.0], G.centroide([[0, 0], [1, 1], [2, 2]])
  end

  def test_girar_90_graus
    x, y = G.girar([[1.0, 0.0]], 90).first
    assert_in_delta 0.0, x, 1e-12
    assert_in_delta 1.0, y, 1e-12
  end

  def test_casco_ignora_pontos_internos
    casco = G.casco_convexo(RETANGULO + [[5, 2], [1, 1]])
    assert_equal RETANGULO.sort, casco.sort
  end

  def test_caixa
    assert_equal [0, 0, 10, 4], G.caixa(RETANGULO)
  end
end
