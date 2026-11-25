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
    RODAPE = 130
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
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@largura} #{@altura}" width="#{@largura}" height="#{@altura}" font-family="#{Estilo::FONTE}">
          <title>#{esc(@titulo || 'Planta de loteamento')}</title>
          <defs>
            <linearGradient id="fundo" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stop-color="#{Estilo::FUNDO_DE}"/>
              <stop offset="1" stop-color="#{Estilo::FUNDO_PARA}"/>
            </linearGradient>
            <filter id="brilho" x="-5%" y="-5%" width="110%" height="110%">
              <feGaussianBlur stdDeviation="2.2" result="b"/>
              <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
            </filter>
          </defs>
          <rect width="#{@largura}" height="#{@altura}" fill="url(#fundo)"/>
        #{titulo_svg}#{quadras_svg}  <g id="lotes" fill="#{Estilo::LOTE}" fill-opacity="0.05" stroke="#{Estilo::LOTE}" stroke-width="1" stroke-linejoin="round" filter="url(#brilho)">
        #{caminhos_dos_lotes}
          </g>
        #{rotulos_svg}#{escala_svg}#{rosa_svg}</svg>
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
      %(  <text x="#{MARGEM}" y="#{MARGEM}" fill="#{Estilo::TEXTO}" font-size="26" font-weight="600">#{esc(@titulo)}</text>\n) +
        %(  <text x="#{MARGEM}" y="#{MARGEM + 24}" fill="#{Estilo::TEXTO_SECUNDARIO}" font-size="14" letter-spacing="1">#{esc(sub)}</text>\n)
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

      %(  <g id="quadras" fill="none" stroke="#{Estilo::QUADRA}" stroke-width="1.6" stroke-opacity="0.55" stroke-dasharray="7 5" stroke-linejoin="round">\n#{contornos}  </g>\n)
    end

    # ── rótulos ────────────────────────────────────────────────────────────────

    def rotulos_svg
      return "" unless @rotulos

      lotes = @figuras.filter_map { |f| rotulo_de_lote(f) }
      lotes = lotes.reject { |r| debaixo_de_quadra?(r) }
      saida = +%(  <g id="rotulos-lotes" fill="#{Estilo::TEXTO}" text-anchor="middle" paint-order="stroke" stroke="#{Estilo::FUNDO_DE}" stroke-width="2.5" stroke-linejoin="round">\n)
      lotes.each { |r| saida << texto_svg(r) }
      saida << "  </g>\n"
      saida << %(  <g id="rotulos-quadras" fill="#{Estilo::QUADRA}" text-anchor="middle" font-weight="700" paint-order="stroke" stroke="#{Estilo::FUNDO_DE}" stroke-width="4" stroke-linejoin="round">\n)
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

    # ── escala e rosa dos ventos ───────────────────────────────────────────────

    def escala_svg
      valor = Escala.valor_redondo(@larg_m * 0.22)
      comprimento = valor * @escala
      x0 = MARGEM
      y0 = (@topo + @mapa_alt).round + 62
      meio = comprimento / 2
      ticks = [[0, "0"], [meio, Escala.formatar(valor / 2.0)], [comprimento, Escala.rotulo(valor)]]
      marcas = ticks.map do |dx, rot|
        %(    <text x="#{format('%.1f', x0 + dx)}" y="#{y0 + 24}" text-anchor="middle">#{esc(rot)}</text>\n)
      end.join
      <<~SVG.gsub(/^(?=.)/, "  ")
        <g id="escala" fill="#{Estilo::AMBAR}" font-size="13">
          <rect x="#{x0}" y="#{y0}" width="#{format('%.1f', meio)}" height="7" fill="#{Estilo::AMBAR}" stroke="#{Estilo::AMBAR}"/>
          <rect x="#{format('%.1f', x0 + meio)}" y="#{y0}" width="#{format('%.1f', meio)}" height="7" fill="none" stroke="#{Estilo::AMBAR}"/>
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
          <circle cx="#{cx}" cy="#{cy}" r="#{r}" fill="none" stroke="#{Estilo::AMBAR}" stroke-opacity="0.5"/>
          <path d="M#{cx} #{cy - r + 4}L#{cx + 9} #{cy + 6}L#{cx} #{cy + 1}L#{cx - 9} #{cy + 6}Z" fill="#{Estilo::AMBAR}" fill-opacity="0.85"/>
          <path d="M#{cx} #{cy + r - 4}L#{cx + 6} #{cy + 6}L#{cx} #{cy + 1}L#{cx - 6} #{cy + 6}Z" fill="#{Estilo::AMBAR}" fill-opacity="0.45"/>
          <text x="#{cx}" y="#{cy - r - 6}" text-anchor="middle" fill="#{Estilo::AMBAR}" font-size="15" font-weight="700">N</text>
        </g>
      SVG
    end
  end
end
