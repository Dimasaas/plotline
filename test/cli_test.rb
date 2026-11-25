# frozen_string_literal: true

require_relative "suporte"
require "open3"
require "tmpdir"
require "rbconfig"

class CliTest < Minitest::Test
  BIN = File.expand_path("../bin/plotline", __dir__)

  def rodar(*args, entrada: nil)
    Open3.capture3(RbConfig.ruby, BIN, *args, stdin_data: entrada.to_s)
  end

  def test_le_arquivo_e_escreve_svg_na_saida
    Dir.mktmpdir do |d|
      arq = File.join(d, "g.geojson")
      File.write(arq, Suporte.grade)
      out, _err, st = rodar(arq)
      assert st.success?
      assert out.start_with?("<svg")
    end
  end

  def test_le_da_entrada_padrao
    out, _err, st = rodar("-", entrada: Suporte.grade)
    assert st.success?
    assert_includes out, "</svg>"
  end

  def test_arquivo_inexistente_sai_com_erro
    _out, err, st = rodar("nao-existe.geojson")
    refute st.success?
    assert_includes err, "plotline:"
  end

  def test_sem_argumento_mostra_uso
    _out, err, st = rodar
    assert_equal 2, st.exitstatus
    assert_includes err, "Uso:"
  end
end
