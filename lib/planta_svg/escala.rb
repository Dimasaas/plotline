# frozen_string_literal: true

module PlantaSvg
  # Valores redondos para a barra de escala: 1, 2 ou 5 vezes uma potência de 10.
  module Escala
    PASSOS = [1, 2, 5].freeze

    module_function

    # Maior valor 1-2-5 que não passa de `alvo` (em metros).
    def valor_redondo(alvo)
      raise ArgumentError, "alvo precisa ser positivo" unless alvo.positive?

      base = 10.0**Math.log10(alvo).floor
      fator = PASSOS.reverse.find { |f| f * base <= alvo * (1 + 1e-12) }
      valor = fator * base
      valor >= 1 ? valor.round : valor
    end

    def rotulo(metros)
      if metros >= 1000
        "#{formatar(metros / 1000.0)} km"
      else
        "#{formatar(metros)} m"
      end
    end

    def formatar(n)
      n == n.round ? n.round.to_s : n.to_s
    end
  end
end
