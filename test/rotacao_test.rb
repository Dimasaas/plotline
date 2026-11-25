# frozen_string_literal: true

require_relative "suporte"

class RotacaoTest < Minitest::Test
  R = PlantaSvg::Rotacao

  def metros(json)
    PlantaSvg::Geojson.ler(json).flat_map(&:anel).map { |lng, lat| Suporte.proj.projetar(lng, lat) }
  end

  def test_planta_inclinada_20_graus_volta_para_os_eixos
    pts = metros(Suporte.grade(quadras: [3, 1], giro: 20.0))
    assert_in_delta(-20.0, R.melhor_giro(pts), 0.01)
  end

  def test_acha_o_angulo_para_varios_giros
    [-70.0, -33.0, 5.0, 41.0, 80.0].each do |g|
      pts = metros(Suporte.grade(quadras: [3, 1], giro: g))
      assert_in_delta(-g, R.melhor_giro(pts), 0.01, "giro #{g}")
    end
  end

  def test_retangulo_resultante_e_o_do_terreno
    ret = R.menor_retangulo(metros(Suporte.grade(quadras: [3, 1], giro: 33.0)))
    assert_in_delta 172.0, ret.largura, 0.01
    assert_in_delta 60.0, ret.altura, 0.01
  end

  def test_planta_em_pe_e_deitada
    pts = metros(Suporte.grade(quadras: [1, 3], giro: 0.0))
    ret = R.menor_retangulo(pts)
    assert_operator ret.largura, :>, ret.altura
    assert_in_delta 90.0, ret.graus.abs, 0.01
  end

  def test_resultado_sempre_em_menos_90_a_90
    [0, 17, 95, 135, 179, 200].each do |g|
      pts = metros(Suporte.grade(quadras: [2, 1], giro: g.to_f))
      graus = R.melhor_giro(pts)
      assert_operator graus, :>, -90.0
      assert_operator graus, :<=, 90.0
    end
  end

  def test_pontos_insuficientes_nao_quebram
    assert_equal 0.0, R.melhor_giro([[0, 0], [5, 1]])
  end

  def test_normalizar
    assert_in_delta 10.0, R.normalizar(190.0), 1e-9
    assert_in_delta(-10.0, R.normalizar(170.0), 1e-9)
    assert_in_delta 90.0, R.normalizar(-90.0), 1e-9
  end
end
