defmodule Formata.YAML.Reader.Sigil do
  def sigil_y(string, [?a]), do: Formata.YAML.Reader.read_from_string!(string, atoms: true)
  def sigil_y(string, []), do: Formata.YAML.Reader.read_from_string!(string)
end
