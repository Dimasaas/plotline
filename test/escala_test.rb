# frozen_string_literal: true

require_relative "suporte"

class EscalaTest < Minitest::Test
  E = PlantaSvg::Escala

  def test_valores_um_dois_cinco
    {
      1 => 1, 1.9 => 1, 2 => 2, 4.9 => 2, 5 => 5, 9.99 => 5, 10 => 10,
      37 => 20, 180 => 100, 250 => 200, 640 => 500, 1000 => 1000, 7300 => 5000
    }.each { |alvo, esperado| assert_equal esperado, E.valor_redondo(alvo), "alvo #{alvo}" }
  end

  def test_valores_menores_que_um_metro
    assert_in_delta 0.5, E.valor_redondo(0.7), 1e-12
  end

  def test_nunca_passa_do_alvo
    (1..2000).step(7) { |a| assert_operator E.valor_redondo(a), :<=, a }
  end

  def test_alvo_invalido
    assert_raises(ArgumentError) { E.valor_redondo(0) }
  end

  def test_rotulos
    assert_equal "200 m", E.rotulo(200)
    assert_equal "1 km", E.rotulo(1000)
    assert_equal "2 km", E.rotulo(2000)
    assert_equal "0.5 m", E.rotulo(0.5)
  end
end
