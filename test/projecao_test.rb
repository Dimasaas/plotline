# frozen_string_literal: true

require_relative "suporte"

class ProjecaoTest < Minitest::Test
  def test_origem_vira_zero
    p = Plotline::Projecao.new(-16.7, -49.25)
    x, y = p.projetar(-49.25, -16.7)
    assert_in_delta 0.0, x, 1e-9
    assert_in_delta 0.0, y, 1e-9
  end

  def test_um_grau_de_latitude_vale_cerca_de_111_km
    p = Plotline::Projecao.new(0, 0)
    assert_in_delta 111_195, p.projetar(0, 1)[1], 5
  end

  def test_longitude_encolhe_com_o_cosseno_da_latitude
    equador = Plotline::Projecao.new(0, 0).projetar(1, 0)[0]
    em_60 = Plotline::Projecao.new(60, 0).projetar(1, 60)[0]
    assert_in_delta equador / 2.0, em_60, 1.0
  end

  def test_ida_e_volta
    p = Plotline::Projecao.new(-16.7, -49.25)
    lng, lat = p.inverter(*p.projetar(-49.2412, -16.6931))
    assert_in_delta(-49.2412, lng, 1e-9)
    assert_in_delta(-16.6931, lat, 1e-9)
  end

  def test_centrada_em_usa_o_meio_da_caixa
    p = Plotline::Projecao.centrada_em([[-50.0, -17.0], [-49.0, -16.0]])
    assert_in_delta(-49.5, p.lng0, 1e-12)
    assert_in_delta(-16.5, p.lat0, 1e-12)
  end

  def test_lote_de_12_por_30_metros_mantem_a_proporcao
    json = JSON.parse(Suporte.grade(quadras: [1, 1], lotes: [1, 1]))
    anel = json["features"][0]["geometry"]["coordinates"][0][0..3]
    pts = anel.map { |lng, lat| Suporte.proj.projetar(lng, lat) }
    assert_in_delta 12.0, (pts[1][0] - pts[0][0]).abs, 1e-6
    assert_in_delta 30.0, (pts[2][1] - pts[1][1]).abs, 1e-6
  end
end
