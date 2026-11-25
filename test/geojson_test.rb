# frozen_string_literal: true

require_relative "suporte"

class GeojsonTest < Minitest::Test
  def test_le_a_grade_sintetica
    lotes = Plotline::Geojson.ler(Suporte.grade)
    assert_equal 32, lotes.size
    assert_equal 4, lotes.first.anel.size # sem o ponto de fechamento
    assert_equal "1", lotes.first.quadra
  end

  def test_aceita_multipolygon_e_nomes_alternativos
    json = {
      "type" => "Feature",
      "properties" => { "nm_qdr" => "7", "nm_lot" => " 3 " },
      "geometry" => { "type" => "MultiPolygon", "coordinates" => [
        [[[0, 0], [1, 0], [1, 1], [0, 0]]],
        [[[2, 2], [3, 2], [3, 3], [2, 2]]]
      ] }
    }
    lotes = Plotline::Geojson.ler(JSON.generate(json))
    assert_equal 2, lotes.size
    assert_equal %w[7 7], lotes.map(&:quadra)
    assert_equal "3", lotes.first.lote
  end

  def test_json_quebrado_vira_erro_nosso
    assert_raises(Plotline::Erro) { Plotline::Geojson.ler("{nope") }
  end

  def test_sem_poligonos_vira_erro
    assert_raises(Plotline::Erro) { Plotline::Geojson.ler('{"type":"FeatureCollection","features":[]}') }
  end

  def test_ignora_aneis_degenerados
    json = '{"type":"Feature","properties":{},"geometry":{"type":"Polygon","coordinates":[[[0,0],[1,1],[0,0]]]}}'
    assert_raises(Plotline::Erro) { Plotline::Geojson.ler(json) }
  end
end
