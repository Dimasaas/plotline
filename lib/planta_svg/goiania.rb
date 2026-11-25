# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require_relative "geometria"

module PlantaSvg
  # Busca a geometria de lotes de um bairro no ArcGIS aberto da Prefeitura de
  # Goiânia (sem chave) e devolve um GeoJSON enxuto.
  #
  # Privacidade por construção: os `outFields` pedidos são só os números de
  # quadra e lote, então nenhum outro atributo (inscrição, proprietário…) sai do
  # servidor; o que ainda assim vier na resposta é descartado ao montar o GeoJSON.
  #
  # A camada de cada nível, como o serviço publica:
  #   2 = divisas de bairro  (nm_bai, id)
  #   1 = divisas de quadra  (id_bai -> bairro, id = id da quadra, nm_qdr = número)
  #   0 = divisas de lote    (id_qdr -> quadra, nm_lot = número)
  class Goiania
    class FonteIndisponivel < PlantaSvg::Erro; end
    class BairroNaoEncontrado < PlantaSvg::Erro; end

    BASE = "https://portalmapa.goiania.go.gov.br/servicogyn/rest/services/MapaServer/Feature_Base/MapServer"
    CAMADA_LOTE = 0
    CAMADA_QUADRA = 1
    CAMADA_BAIRRO = 2
    PAGINA = 1000
    QUADRAS_POR_CONSULTA = 50
    TENTATIVAS = 3

    attr_reader :bairro_encontrado

    # `http` é um chamável (url, params) -> texto da resposta; existe para os
    # testes trocarem a rede por respostas gravadas.
    def initialize(base: BASE, timeout: 60, http: nil, espera: ->(s) { sleep(s) })
      @base = base.chomp("/")
      @timeout = timeout
      @http = http || method(:post)
      @espera = espera
    end

    # => Hash no formato GeoJSON FeatureCollection
    def geojson(nome)
      bairro = achar_bairro(nome)
      @bairro_encontrado = bairro[:nome]
      quadras = quadras_do(bairro[:id])
      raise BairroNaoEncontrado, "o bairro #{bairro[:nome].inspect} não tem quadras no serviço" if quadras.empty?

      feicoes = lotes_das(quadras.keys).filter_map { |f| montar(f, quadras) }
      raise BairroNaoEncontrado, "o bairro #{bairro[:nome].inspect} não devolveu lotes" if feicoes.empty?

      { "type" => "FeatureCollection", "features" => feicoes }
    end

    # "Setor Sul" -> "sul": o serviço grava os nomes sem a palavra "Setor".
    def self.normalizar(nome)
      limpo = nome.to_s.strip.downcase.tr("áàâãäéèêëíìîïóòôõöúùûüç", "aaaaaeeeeiiiiooooouuuuc")
      limpo.sub(/\Asetor\s+/, "").squeeze(" ")
    end

    private

    def achar_bairro(nome)
      alvo = self.class.normalizar(nome)
      raise BairroNaoEncontrado, "informe o nome do bairro" if alvo.empty?

      achados = consultar(CAMADA_BAIRRO,
                          "where" => "UPPER(nm_bai) LIKE UPPER('%#{aspas(alvo)}%')",
                          "outFields" => "nm_bai,id", "returnGeometry" => "false")
                .map { |f| { nome: f.dig("attributes", "nm_bai").to_s, id: f.dig("attributes", "id").to_s } }
      raise BairroNaoEncontrado, "nenhum bairro parecido com #{nome.inspect}" if achados.empty?

      exatos = achados.select { |b| self.class.normalizar(b[:nome]) == alvo }
      escolhidos = exatos.empty? ? achados : exatos
      return escolhidos.first if escolhidos.map { |b| b[:id] }.uniq.size == 1

      lista = escolhidos.map { |b| "#{b[:nome]} (#{b[:id]})" }.join(", ")
      raise BairroNaoEncontrado, "#{nome.inspect} é ambíguo: #{lista}"
    end

    # { id_da_quadra => número } sem as áreas públicas ("AREA").
    def quadras_do(id_bairro)
      consultar(CAMADA_QUADRA,
                "where" => "id_bai = '#{aspas(id_bairro)}'",
                "outFields" => "id,nm_qdr", "returnGeometry" => "false")
        .each_with_object({}) do |f, h|
          numero = f.dig("attributes", "nm_qdr").to_s.strip
          h[f.dig("attributes", "id").to_s] = numero unless numero.empty? || numero.casecmp?("AREA")
        end
    end

    def lotes_das(ids)
      ids.each_slice(QUADRAS_POR_CONSULTA).flat_map do |fatia|
        lista = fatia.map { |i| "'#{aspas(i)}'" }.join(",")
        paginado(CAMADA_LOTE, "where" => "id_qdr IN (#{lista})", "outFields" => "id_qdr,nm_lot",
                              "returnGeometry" => "true", "outSR" => "4326")
      end
    end

    # Segue `exceededTransferLimit`: ler menos do que existe e não avisar seria
    # mentir o total.
    def paginado(camada, params)
      todas = []
      deslocamento = 0
      loop do
        corpo = executar(camada, params.merge("resultOffset" => deslocamento.to_s,
                                              "resultRecordCount" => PAGINA.to_s))
        pagina = Array(corpo["features"])
        todas.concat(pagina)
        break unless corpo["exceededTransferLimit"] && !pagina.empty?

        deslocamento += pagina.size
      end
      todas
    end

    def consultar(camada, params) = Array(executar(camada, params)["features"])

    def executar(camada, params)
      url = "#{@base}/#{camada}/query"
      corpo = nil
      TENTATIVAS.times do |i|
        corpo = JSON.parse(@http.call(url, params.merge("f" => "json")))
        break
      rescue JSON::ParserError, SystemCallError, IOError, Timeout::Error, SocketError, Net::HTTPExceptions => e
        raise FonteIndisponivel, "o portal da prefeitura não respondeu (#{e.class})" if i == TENTATIVAS - 1

        @espera.call(2**i)
      end
      # O ArcGIS responde HTTP 200 com {"error": ...} no corpo quando recusa a consulta.
      raise PlantaSvg::Erro, "o portal recusou a consulta: #{corpo['error']['message'] || corpo['error']['code']}" if corpo["error"]

      corpo
    end

    def post(url, params)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = http.read_timeout = @timeout
      resposta = http.request(Net::HTTP::Post.new(uri).tap { |r| r.set_form_data(params) })
      raise IOError, "HTTP #{resposta.code}" unless resposta.is_a?(Net::HTTPSuccess)

      resposta.body.to_s.force_encoding("UTF-8")
    end

    # Só geometria + números de quadra e lote. Qualquer outro atributo é ignorado.
    def montar(feicao, quadras)
      attrs = feicao["attributes"] || {}
      return nil unless quadras.key?(attrs["id_qdr"].to_s)

      aneis = Array(feicao.dig("geometry", "rings")).select { |a| a.size >= 4 }
      return nil if aneis.empty?

      anel = aneis.max_by { |a| area(a) }.map { |lng, lat| [lng.round(7), lat.round(7)] }
      {
        "type" => "Feature",
        "properties" => { "quadra" => quadras[attrs["id_qdr"].to_s], "lote" => attrs["nm_lot"].to_s.strip },
        "geometry" => { "type" => "Polygon", "coordinates" => [anel] }
      }
    end

    def area(anel) = Geometria.area(anel.map { |p| [p[0], p[1]] })

    def aspas(texto) = texto.to_s.gsub("'", "''")
  end
end
