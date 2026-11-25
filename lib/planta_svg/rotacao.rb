# frozen_string_literal: true

require_relative "geometria"

module PlantaSvg
  # Menor retângulo envolvente de um conjunto de pontos.
  #   graus   - giro anti-horário (y para cima) que alinha o retângulo aos eixos,
  #             já normalizado para (-90, 90] e com o lado maior na horizontal;
  #   largura - lado maior; altura - lado menor.
  Retangulo = Struct.new(:graus, :largura, :altura)

  # Escolhe a rotação da planta. Para o retângulo de área mínima, um dos lados
  # coincide com uma aresta do casco convexo; então basta testar cada aresta do
  # casco (e não varrer ângulos de grau em grau): o resultado é exato.
  module Rotacao
    TOLERANCIA = 1e-9

    module_function

    def menor_retangulo(pts)
      casco = Geometria.casco_convexo(pts)
      return caixa_simples(pts) if casco.size < 3

      melhor = nil
      casco.each_with_index do |p, i|
        q = casco[(i + 1) % casco.size]
        graus = -Math.atan2(q[1] - p[1], q[0] - p[0]) * 180.0 / Math::PI
        minx, miny, maxx, maxy = Geometria.caixa(Geometria.girar(casco, graus))
        larg = maxx - minx
        alt = maxy - miny
        # O retângulo girado 90 graus tem a mesma área: desempata pelo formato,
        # deixando o lado maior na horizontal (planta "deitada").
        if alt > larg
          graus += 90.0
          larg, alt = alt, larg
        end
        cand = Retangulo.new(normalizar(graus), larg, alt)
        melhor = cand if melhor.nil? || melhor?(cand, melhor)
      end
      melhor
    end

    # Giro, em graus anti-horários, que deixa a planta mais deitada.
    def melhor_giro(pts) = menor_retangulo(pts).graus

    # Leva qualquer ângulo para (-90, 90]. Girar 180 graus não muda a caixa, então
    # fica o giro de menor módulo: o norte continua perto do topo da folha.
    def normalizar(graus)
      g = graus.round(9) % 180.0
      g -= 180.0 if g > 90.0
      g
    end

    def melhor?(cand, atual)
      a1 = cand.largura * cand.altura
      a2 = atual.largura * atual.altura
      return a1 < a2 if (a1 - a2).abs > TOLERANCIA * [a1, a2].max

      cand.graus.abs < atual.graus.abs
    end

    def caixa_simples(pts)
      minx, miny, maxx, maxy = Geometria.caixa(pts)
      larg = maxx - minx
      alt = maxy - miny
      larg >= alt ? Retangulo.new(0.0, larg, alt) : Retangulo.new(90.0, alt, larg)
    end
  end
end
