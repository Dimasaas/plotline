# frozen_string_literal: true

require_relative "estilo"
require_relative "geometria"
require_relative "projecao"

module PlantaSvg
  # Recebe lotes (lng/lat) e devolve o SVG da planta.
  class Desenho
    MARGEM = 60

    def initialize(lotes, largura: 1600)
      raise Erro, "sem lotes para desenhar" if lotes.empty?

      @lotes = lotes
      @largura = largura
    end

    def para_svg
      preparar
      montar
    end

    private

    def preparar
      todos = @lotes.flat_map(&:anel)
      proj = Projecao.centrada_em(todos)
      @figuras = @lotes.map do |l|
        { lote: l, pts: l.anel.map { |lng, lat| proj.projetar(lng, lat) } }
      end

      xs = @figuras.flat_map { |f| f[:pts].map(&:first) }
      ys = @figuras.flat_map { |f| f[:pts].map(&:last) }
      @minx = xs.min
      @maxy = ys.max
      larg_m = xs.max - @minx
      alt_m = @maxy - ys.min
      raise Erro, "os lotes não têm extensão" if larg_m <= 0 || alt_m <= 0

      @escala = (@largura - (2 * MARGEM)) / larg_m # unidades do SVG por metro
      @altura = ((alt_m * @escala) + (2 * MARGEM)).ceil
    end

    # metros -> coordenadas do SVG (y invertido: norte para cima).
    def ponto(x, y)
      [MARGEM + ((x - @minx) * @escala), MARGEM + ((@maxy - y) * @escala)]
    end

    def montar
      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@largura} #{@altura}" width="#{@largura}" height="#{@altura}" font-family="#{Estilo::FONTE}">
          <title>Planta de loteamento</title>
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
          <g id="lotes" fill="#{Estilo::LOTE}" fill-opacity="0.05" stroke="#{Estilo::LOTE}" stroke-width="1" stroke-linejoin="round" filter="url(#brilho)">
        #{caminhos_dos_lotes}
          </g>
        </svg>
      SVG
    end

    def caminhos_dos_lotes
      @figuras.map { |f| "    <path d=\"#{caminho(f[:pts])}\"/>" }.join("\n")
    end

    def caminho(pts)
      "M#{pts.map { |x, y| format('%.1f %.1f', *ponto(x, y)) }.join('L')}Z"
    end
  end
end
