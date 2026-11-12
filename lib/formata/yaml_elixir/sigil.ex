defmodule Formata.YamlElixir.Sigil do
  def sigil_y(string, [?a]), do: Formata.YamlElixir.read_from_string!(string, atoms: true)
  def sigil_y(string, []), do: Formata.YamlElixir.read_from_string!(string)
end
