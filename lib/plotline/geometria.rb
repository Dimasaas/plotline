# frozen_string_literal: true

module Plotline
  # Funções puras sobre polígonos planos (listas de [x, y]).
  module Geometria
    module_function

    # Área com sinal pela fórmula do cadarço; positiva no sentido anti-horário.
    def area_com_sinal(pts)
      soma = 0.0
      pts.each_with_index do |(x1, y1), i|
        x2, y2 = pts[(i + 1) % pts.size]
        soma += (x1 * y2) - (x2 * y1)
      end
      soma / 2.0
    end

    def area(pts) = area_com_sinal(pts).abs

    # Centroide do polígono. Se a área é nula (pontos alinhados), cai na média.
    def centroide(pts)
      a = area_com_sinal(pts)
      return media(pts) if a.abs < 1e-9

      cx = cy = 0.0
      pts.each_with_index do |(x1, y1), i|
        x2, y2 = pts[(i + 1) % pts.size]
        cruz = (x1 * y2) - (x2 * y1)
        cx += (x1 + x2) * cruz
        cy += (y1 + y2) * cruz
      end
      [cx / (6.0 * a), cy / (6.0 * a)]
    end

    def media(pts)
      [pts.sum { |p| p[0] } / pts.size.to_f, pts.sum { |p| p[1] } / pts.size.to_f]
    end

    # => [minx, miny, maxx, maxy]
    def caixa(pts)
      xs = pts.map(&:first)
      ys = pts.map(&:last)
      [xs.min, ys.min, xs.max, ys.max]
    end

    # Gira os pontos em torno da origem, `graus` no sentido anti-horário
    # (com y para cima).
    def girar(pts, graus)
      rad = graus * Math::PI / 180.0
      c = Math.cos(rad)
      s = Math.sin(rad)
      pts.map { |x, y| [(x * c) - (y * s), (x * s) + (y * c)] }
    end

    # Casco convexo (monotone chain), em sentido anti-horário.
    def casco_convexo(pts)
      unicos = pts.uniq.sort
      return unicos if unicos.size < 3

      cruz = ->(o, a, b) { ((a[0] - o[0]) * (b[1] - o[1])) - ((a[1] - o[1]) * (b[0] - o[0])) }
      monta = lambda do |lista|
        lista.each_with_object([]) do |p, cadeia|
          cadeia.pop while cadeia.size >= 2 && cruz.call(cadeia[-2], cadeia[-1], p) <= 0
          cadeia << p
        end
      end
      baixo = monta.call(unicos)
      alto = monta.call(unicos.reverse)
      baixo[0...-1] + alto[0...-1]
    end
  end
end
