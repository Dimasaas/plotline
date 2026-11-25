# frozen_string_literal: true

require_relative "suporte"
require "planta_svg/goiania"

# Nenhum teste aqui usa rede: o ArcGIS é simulado com respostas montadas à mão.
class GoianiaTest < Minitest::Test
  G = PlantaSvg::Goiania

  def anel(x, y) = [[x, y], [x, y + 0.0001], [x + 0.0001, y + 0.0001], [x + 0.0001, y], [x, y]]

  # Simula o servidor e registra o que foi pedido.
  class Falso
    attr_reader :chamadas

    def initialize(bairros: [{ "nm_bai" => "Sul", "id" => "B1" }], pagina_lotes: 1000)
      @bairros = bairros
      @pagina_lotes = pagina_lotes
      @chamadas = []
      @lotes = (0...5).map do |i|
        { "attributes" => { "id_qdr" => i < 3 ? "Q-A" : "Q-B", "nm_lot" => (i + 1).to_s,
                            "ci" => "0000000000", "proprietario" => "FULANO" },
          "geometry" => { "rings" => [[[-49.25 + (i * 0.001), -16.7], [-49.25 + (i * 0.001), -16.699],
                                       [-49.249 + (i * 0.001), -16.699], [-49.249 + (i * 0.001), -16.7],
                                       [-49.25 + (i * 0.001), -16.7]]] } }
      end
    end

    def call(url, params)
      @chamadas << [url[%r{/(\d)/query}, 1].to_i, params]
      corpo =
        case @chamadas.last[0]
        when 2 then { "features" => @bairros.map { |b| { "attributes" => b } } }
        when 1 then { "features" => [{ "attributes" => { "id" => "Q-A", "nm_qdr" => "1" } },
                                     { "attributes" => { "id" => "Q-B", "nm_qdr" => "AREA" } },
                                     { "attributes" => { "id" => "Q-C", "nm_qdr" => "2" } }] }
        else
          off = params["resultOffset"].to_i
          pedaco = @lotes[off, @pagina_lotes] || []
          { "features" => pedaco, "exceededTransferLimit" => off + @pagina_lotes < @lotes.size }
        end
      JSON.generate(corpo)
    end
  end

  def fonte(falso, **o) = G.new(http: falso, espera: ->(_) {}, **o)

  def test_monta_geojson_so_com_quadra_e_lote
    dados = fonte(Falso.new).geojson("Setor Sul")
    assert_equal "FeatureCollection", dados["type"]
    assert_equal 3, dados["features"].size # lotes da quadra "AREA" ficam de fora
    props = dados["features"].map { |f| f["properties"] }
    assert(props.all? { |p| p.keys.sort == %w[lote quadra] })
    assert_equal %w[1 2 3], props.map { |p| p["lote"] }
  end

  def test_nenhum_atributo_pessoal_vai_para_a_saida
    texto = JSON.generate(fonte(Falso.new).geojson("Sul"))
    refute_includes texto, "FULANO"
    refute_includes texto, "0000000000"
    refute_includes texto, "proprietario"
  end

  def test_so_pede_quadra_e_lote_ao_servidor
    falso = Falso.new
    fonte(falso).geojson("Sul")
    campos = falso.chamadas.map { |_, p| p["outFields"] }
    assert_includes campos, "id_qdr,nm_lot"
    refute(campos.any? { |c| c.include?("ci") || c == "*" })
  end

  def test_pede_coordenadas_em_graus
    falso = Falso.new
    fonte(falso).geojson("Sul")
    assert_equal "4326", falso.chamadas.find { |c, _| c.zero? }[1]["outSR"]
  end

  def test_segue_a_paginacao
    falso = Falso.new(pagina_lotes: 2)
    dados = fonte(falso).geojson("Sul")
    assert_equal 3, dados["features"].size
    assert_operator falso.chamadas.count { |c, _| c.zero? }, :>=, 3
  end

  def test_normaliza_o_nome
    assert_equal "sul", G.normalizar("  Setor  SUL ")
    assert_equal "ceu azul", G.normalizar("Céu Azul")
  end

  def test_bairro_inexistente
    vazio = ->(_u, _p) { '{"features":[]}' }
    assert_raises(G::BairroNaoEncontrado) { fonte(vazio).geojson("Nada") }
  end

  def test_nome_ambiguo_lista_os_candidatos
    falso = Falso.new(bairros: [{ "nm_bai" => "Sul A", "id" => "1" }, { "nm_bai" => "Sul B", "id" => "2" }])
    erro = assert_raises(G::BairroNaoEncontrado) { fonte(falso).geojson("Sul") }
    assert_includes erro.message, "Sul A"
    assert_includes erro.message, "Sul B"
  end

  def test_nome_exato_vence_os_parecidos
    falso = Falso.new(bairros: [{ "nm_bai" => "Colorado Sul", "id" => "9" }, { "nm_bai" => "Sul", "id" => "1" }])
    f = fonte(falso)
    f.geojson("Sul")
    assert_equal "Sul", f.bairro_encontrado
  end

  def test_erro_no_corpo_com_status_200_e_levantado
    recusa = ->(_u, _p) { '{"error":{"code":400,"message":"campo inválido"}}' }
    erro = assert_raises(PlantaSvg::Erro) { fonte(recusa).geojson("Sul") }
    assert_includes erro.message, "campo inválido"
  end

  def test_tenta_de_novo_e_depois_desiste
    n = 0
    quebrado = lambda do |_u, _p|
      n += 1
      raise IOError, "caiu"
    end
    assert_raises(G::FonteIndisponivel) { fonte(quebrado).geojson("Sul") }
    assert_equal G::TENTATIVAS, n
  end

def test_aspas_no_nome_nao_quebram_a_consulta
  falso = Falso.new
  fonte(falso).geojson("d'agua")
  assert_includes falso.chamadas.first[1]["where"], "d''agua"
end

  def test_saida_alimenta_o_desenhista
    svg = PlantaSvg.converter(JSON.generate(fonte(Falso.new).geojson("Sul")))
    assert_includes svg, "</svg>"
  end
end
