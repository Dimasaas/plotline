# frozen_string_literal: true

require "cgi"
require_relative "estilo"
require_relative "escala"
require_relative "geometria"
require_relative "projecao"
require_relative "rotacao"

module Plotline
  # Recebe lotes (lng/lat) e devolve o SVG da planta.
  #
  # Opções:
  #   largura:  largura do viewBox (padrão 1600)
  #   giro:     :auto (menor retângulo envolvente) ou graus anti-horários
  #   rotulos:  desenha números de lote e de quadra (padrão true)
  #   titulo:   texto opcional no topo
  class Desenho
    MARGEM = 60
    TOPO_TITULO = 56
    RODAPE = 150
    LARGURA_CARACTERE = 0.6   # largura média de um caractere, em múltiplos do corpo
    CORPO_MAX_LOTE = 14.0
    CORPO_MIN_LOTE = 4.5

    def initialize(lotes, largura: 1600, giro: :auto, rotulos: true, titulo: nil)
      raise Erro, "sem lotes para desenhar" if lotes.empty?
      raise Erro, "a largura precisa ser maior que #{2 * MARGEM}" unless largura.to_i > 2 * MARGEM

      @lotes = lotes
      @largura = largura.to_i
      @giro_pedido = giro
      @rotulos = rotulos
      @titulo = titulo
    end

    # Giro aplicado (graus anti-horários); válido depois de `para_svg`.
    attr_reader :giro

    def para_svg
      preparar
      montar
    end

    private

    def preparar
      proj = Projecao.centrada_em(@lotes.flat_map(&:anel))
      metros = @lotes.map { |l| l.anel.map { |lng, lat| proj.projetar(lng, lat) } }

      todos = metros.flatten(1)
      @giro = @giro_pedido == :auto ? Rotacao.melhor_giro(todos) : @giro_pedido.to_f
      @figuras = @lotes.each_with_index.map do |l, i|
        { lote: l, pts: Geometria.girar(metros[i], @giro) }
      end

      minx, miny, maxx, maxy = Geometria.caixa(@figuras.flat_map { |f| f[:pts] })
      @minx = minx
      @maxy = maxy
      @larg_m = maxx - minx
      alt_m = maxy - miny
      raise Erro, "os lotes não têm extensão" if @larg_m <= 0 || alt_m <= 0

      @escala = (@largura - (2 * MARGEM)) / @larg_m # unidades do SVG por metro
      @topo = MARGEM + (@titulo ? TOPO_TITULO : 0)
      @mapa_alt = alt_m * @escala
      @altura = (@topo + @mapa_alt + RODAPE).ceil
    end

    # metros (já girados) -> coordenadas do SVG; y invertido, norte para cima.
    def ponto(x, y)
      [MARGEM + ((x - @minx) * @escala), @topo + ((@maxy - y) * @escala)]
    end

    def montar
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@largura} #{@altura}" width="#{@largura}" height="#{@altura}" font-family="#{Estilo::FONTE_TECNICA}">
          <title>#{esc(@titulo || 'Planta de loteamento')}</title>
          <defs>
            <pattern id="prancha-fina" width="40" height="40" patternUnits="userSpaceOnUse">
              <path d="M40 0H0V40" fill="none" stroke="#{Estilo::GRAFITE}" stroke-opacity="0.14" stroke-width="0.6"/>
            </pattern>
            <pattern id="prancha-grossa" width="200" height="200" patternUnits="userSpaceOnUse">
              <path d="M200 0H0V200" fill="none" stroke="#{Estilo::GRAFITE}" stroke-opacity="0.22" stroke-width="0.9"/>
            </pattern>
          </defs>
          <rect width="#{@largura}" height="#{@altura}" fill="#{Estilo::PAPEL}"/>
          <rect width="#{@largura}" height="#{@altura}" fill="url(#prancha-fina)"/>
          <rect width="#{@largura}" height="#{@altura}" fill="url(#prancha-grossa)"/>
          <rect x="18" y="18" width="#{@largura - 36}" height="#{@altura - 36}" fill="none" stroke="#{Estilo::TINTA}" stroke-width="2.5"/>
          <rect x="26" y="26" width="#{@largura - 52}" height="#{@altura - 52}" fill="none" stroke="#{Estilo::TINTA}" stroke-width="0.8"/>
        #{titulo_svg}#{quadras_svg}  <g id="lotes" fill="#{Estilo::MUSGO}" fill-opacity="0.2" stroke="#{Estilo::TINTA}" stroke-width="0.8" stroke-linejoin="round">
        #{caminhos_dos_lotes}
          </g>
        #{rotulos_svg}#{cota_svg}#{carimbo_svg}#{escala_svg}#{rosa_svg}</svg>
      SVG
    end

    def esc(texto) = CGI.escapeHTML(texto.to_s)

    def caminhos_dos_lotes
      @figuras.map { |f| "    <path d=\"#{caminho(f[:pts])}\"/>" }.join("\n")
    end

    def caminho(pts)
      "M#{pts.map { |x, y| format('%.1f %.1f', *ponto(x, y)) }.join('L')}Z"
    end

    def titulo_svg
      return "" unless @titulo

      sub = "#{@lotes.size} lotes"
      sub += " · #{quadras.size} quadras" unless quadras.empty?
      %(  <text x="#{MARGEM}" y="#{MARGEM}" fill="#{Estilo::TINTA}" font-family="#{Estilo::FONTE_TITULO}" font-size="28" font-weight="700">#{esc(@titulo)}</text>\n) +
        %(  <text x="#{MARGEM}" y="#{MARGEM + 24}" fill="#{Estilo::GRAFITE}" font-size="14" letter-spacing="1">#{esc(sub)}</text>\n)
    end

    # ── quadras ────────────────────────────────────────────────────────────────

    # { "12" => [pontos de todos os lotes da quadra] }
    def quadras
      @quadras ||= @figuras.each_with_object({}) do |f, h|
        q = f[:lote].quadra
        (h[q] ||= []).concat(f[:pts]) if q
      end
    end

    # Rótulos de quadra: posição, ângulo e corpo, em unidades do SVG.
    def rotulos_de_quadra
      @rotulos_de_quadra ||= quadras.map do |nome, pts|
        centros = @figuras.select { |f| f[:lote].quadra == nome }.map { |f| Geometria.centroide(f[:pts]) }
        cx, cy = ponto(*Geometria.media(centros))
        ret = Rotacao.menor_retangulo(pts)
        texto = nome.match?(/\A\d/) ? "Q#{nome}" : nome
        corpo = [[ret.altura * @escala * 0.32, 34.0].min, 11.0].max
        corpo = [corpo, ret.largura * @escala * 0.9 / (texto.size * LARGURA_CARACTERE)].min
        { texto: texto, x: cx, y: cy, graus: ret.graus, corpo: corpo, pts: pts }
      end
    end

    def quadras_svg
      return "" unless @rotulos

      contornos = rotulos_de_quadra.map do |r|
        casco = Geometria.casco_convexo(r[:pts])
        next if casco.size < 3

        %(    <path d="#{caminho(casco)}"/>\n)
      end.compact.join
      return "" if contornos.empty?

      %(  <g id="quadras" fill="none" stroke="#{Estilo::LEVANTAMENTO}" stroke-width="1.8" stroke-dasharray="9 4 2 4" stroke-linejoin="round">\n#{contornos}  </g>\n)
    end

    # ── rótulos ────────────────────────────────────────────────────────────────

    def rotulos_svg
      return "" unless @rotulos

      lotes = @figuras.filter_map { |f| rotulo_de_lote(f) }
      lotes = lotes.reject { |r| debaixo_de_quadra?(r) }
      saida = +%(  <g id="rotulos-lotes" fill="#{Estilo::GRAFITE}" text-anchor="middle" paint-order="stroke" stroke="#{Estilo::PAPEL}" stroke-width="2.5" stroke-linejoin="round">\n)
      lotes.each { |r| saida << texto_svg(r) }
      saida << "  </g>\n"
      saida << %(  <g id="rotulos-quadras" fill="#{Estilo::TINTA}" text-anchor="middle" font-weight="700" paint-order="stroke" stroke="#{Estilo::PAPEL}" stroke-width="4" stroke-linejoin="round">\n)
      rotulos_de_quadra.each { |r| saida << texto_svg(r) }
      saida << "  </g>\n"
    end

    def texto_svg(r)
      angulo = r[:graus].abs < 0.05 ? "" : %( transform="rotate(#{format('%.1f', r[:graus])} #{format('%.1f', r[:x])} #{format('%.1f', r[:y])})")
      %(    <text x="#{format('%.1f', r[:x])}" y="#{format('%.1f', r[:y])}" font-size="#{format('%.1f', r[:corpo])}" dy="0.35em"#{angulo}>#{esc(r[:texto])}</text>\n)
    end

    # O número do lote vai no centroide. O texto segue o lado maior do lote; se o
    # lote é "em pé" e o número cabe melhor na horizontal, fica na horizontal.
    def rotulo_de_lote(figura)
      texto = figura[:lote].lote
      return nil if texto.nil? || texto.empty?

      ret = Rotacao.menor_retangulo(figura[:pts])
      cx, cy = ponto(*Geometria.centroide(figura[:pts]))
      comprimento = ret.largura * @escala
      largura_lado = ret.altura * @escala
      graus = encaixar(ret.graus)
      corpo = corpo_que_cabe(texto, comprimento, largura_lado)

      if graus.abs >= 45
        na_horizontal = corpo_que_cabe(texto, largura_lado, comprimento)
        if na_horizontal >= corpo * 0.75
          corpo = na_horizontal
          graus = 0.0
        end
      end
      return nil if corpo < CORPO_MIN_LOTE

      { texto: texto, x: cx, y: cy, graus: graus, corpo: corpo }
    end

    def corpo_que_cabe(texto, ao_longo, atravessado)
      [ao_longo * 0.8 / (texto.size * LARGURA_CARACTERE), atravessado * 0.5, CORPO_MAX_LOTE].min
    end

    # Ruído de poucos graus vira 0 ou 90; ninguém quer texto torto por acaso.
    def encaixar(graus)
      return 0.0 if graus.abs < 6
      return (graus.positive? ? 90.0 : -90.0) if graus.abs > 84

      graus
    end

    # Descarta o número do lote que cairia debaixo do rótulo da quadra.
    def debaixo_de_quadra?(lote)
      rotulos_de_quadra.any? do |q|
        rad = -q[:graus] * Math::PI / 180.0
        dx = lote[:x] - q[:x]
        dy = lote[:y] - q[:y]
        u = (dx * Math.cos(rad)) - (dy * Math.sin(rad))
        v = (dx * Math.sin(rad)) + (dy * Math.cos(rad))
        meia_larg = (q[:texto].size * LARGURA_CARACTERE * q[:corpo] / 2) + lote[:corpo]
        u.abs < meia_larg && v.abs < (q[:corpo] * 0.7) + (lote[:corpo] / 2)
      end
    end

    # Cota da largura do terreno (no sentido da planta girada), abaixo do mapa.
    def cota_svg
      y = (@topo + @mapa_alt).round + 18
      x0 = MARGEM
      x1 = (MARGEM + (@larg_m * @escala)).round(1)
      metros = Escala.rotulo(@larg_m.round).tr(".", ",")
      <<~SVG.gsub(/^(?=.)/, "  ")
        <g id="cota" stroke="#{Estilo::LEVANTAMENTO}" stroke-width="1.2" fill="none">
          <path d="M#{x0} #{y}H#{x1}M#{x0} #{y - 6}V#{y + 6}M#{x1} #{y - 6}V#{y + 6}"/>
          <path d="M#{x0} #{y}l9 -3.5v7zM#{x1} #{y}l-9 -3.5v7z" fill="#{Estilo::LEVANTAMENTO}" stroke="none"/>
          <text x="#{format('%.1f', (x0 + x1) / 2)}" y="#{y + 20}" text-anchor="middle" fill="#{Estilo::TINTA}" stroke="none" font-size="12">#{esc(metros)}</text>
        </g>
      SVG
    end

    # Carimbo de prancha técnica no rodapé, entre a escala e a rosa dos ventos.
    def carimbo_svg
      x0 = (@largura * 0.42).round
      x1 = @largura - MARGEM - 110
      return "" if x1 - x0 < 300

      y0 = (@topo + @mapa_alt).round + 52
      larg = x1 - x0
      alt = 66
      meio = x0 + (larg * 0.62).round
      sub = "#{@lotes.size} lotes"
      sub += " · #{quadras.size} quadras" unless quadras.empty?
      nome = @titulo || "Planta de loteamento"
      <<~SVG.gsub(/^(?=.)/, "  ")
        <g id="carimbo" fill="none" stroke="#{Estilo::TINTA}" stroke-width="1.2">
          <rect x="#{x0}" y="#{y0}" width="#{larg}" height="#{alt}"/>
          <path d="M#{meio} #{y0}V#{y0 + alt}M#{x0} #{y0 + 36}H#{x1}"/>
          <g stroke="none" fill="#{Estilo::GRAFITE}" font-size="10" letter-spacing="1">
            <text x="#{x0 + 8}" y="#{y0 + 14}">PRANCHA</text>
            <text x="#{meio + 8}" y="#{y0 + 14}">FOLHA</text>
            <text x="#{x0 + 8}" y="#{y0 + 50}">LEVANTAMENTO</text>
            <text x="#{meio + 8}" y="#{y0 + 50}">GIRO</text>
          </g>
          <g stroke="none" fill="#{Estilo::TINTA}">
            <text x="#{x0 + 8}" y="#{y0 + 30}" font-family="#{Estilo::FONTE_TITULO}" font-size="15" font-weight="700">#{esc(nome)}</text>
            <text x="#{meio + 8}" y="#{y0 + 30}" font-size="13">01 / 01</text>
            <text x="#{x0 + 8}" y="#{y0 + 62}" font-size="12">#{esc(sub)}</text>
            <text x="#{meio + 8}" y="#{y0 + 62}" font-size="12">#{esc(format('%.1f', @giro))}°</text>
          </g>
        </g>
      SVG
    end

    # ── escala e rosa dos ventos ───────────────────────────────────────────────

    def escala_svg
      valor = Escala.valor_redondo(@larg_m * 0.22)
      comprimento = valor * @escala
      x0 = MARGEM
      y0 = (@topo + @mapa_alt).round + 62
      meio = comprimento / 2
      ticks = [[0, "0"], [meio, Escala.formatar(valor / 2.0)], [comprimento, Escala.rotulo(valor)]]
      marcas = ticks.map do |dx, rot|
        %(    <text x="#{format('%.1f', x0 + dx)}" y="#{y0 + 24}" text-anchor="middle">#{esc(rot)}</text>
)
      end.join
      <<~SVG.gsub(/^(?=.)/, "  ")
        <g id="escala" fill="#{Estilo::TINTA}" font-size="13">
          <rect x="#{x0}" y="#{y0}" width="#{format('%.1f', meio)}" height="7" fill="#{Estilo::TINTA}" stroke="#{Estilo::TINTA}"/>
          <rect x="#{format('%.1f', x0 + meio)}" y="#{y0}" width="#{format('%.1f', meio)}" height="7" fill="#{Estilo::PAPEL}" stroke="#{Estilo::TINTA}"/>
        #{marcas}</g>
      SVG
    end

    # A rosa gira ao contrário da planta: a planta foi girada `giro` graus
    # anti-horários, então o norte passou a apontar -giro graus no sentido
    # horário (convenção do `rotate` do SVG).
    def rosa_svg
      cx = @largura - MARGEM - 40
      cy = (@topo + @mapa_alt).round + 66
      r = 32
      <<~SVG.gsub(/^(?=.)/, "  ")
        <g id="rosa-dos-ventos" transform="rotate(#{format('%.2f', -@giro)} #{cx} #{cy})">
          <circle cx="#{cx}" cy="#{cy}" r="#{r}" fill="none" stroke="#{Estilo::TINTA}" stroke-width="1.2"/>
          <circle cx="#{cx}" cy="#{cy}" r="#{r - 7}" fill="none" stroke="#{Estilo::GRAFITE}" stroke-width="0.8"/>
          <path d="M#{cx - r - 6} #{cy}H#{cx + r + 6}M#{cx} #{cy - r}V#{cy + r + 6}" stroke="#{Estilo::TINTA}" stroke-width="0.8"/>
          <path d="M#{cx} #{cy - r + 2}L#{cx + 8} #{cy + 4}L#{cx} #{cy}L#{cx - 8} #{cy + 4}Z" fill="#{Estilo::LEVANTAMENTO}"/>
          <path d="M#{cx} #{cy + r - 2}L#{cx + 6} #{cy + 4}L#{cx} #{cy}L#{cx - 6} #{cy + 4}Z" fill="#{Estilo::TINTA}"/>
          <text x="#{cx}" y="#{cy - r - 6}" text-anchor="middle" fill="#{Estilo::TINTA}" font-size="15" font-weight="700">N</text>
        </g>
      SVG
    end
  end
end
