defmodule Formata.NamespaceTest do
  use ExUnit.Case, async: true

  test "the application ships only the new backend namespaces" do
    modules = Application.spec(:formata, :modules)

    for module <- [
          Formata.JSON.Backend,
          Formata.JSON.Backend.Encoder,
          Formata.TOML,
          Formata.YAML.Reader,
          Formata.YAML.Writer,
          Formata.YAML.Writer.Encoder,
          Formata.NativeSchema,
          Formata.NativeSchema.Error,
          Formata.NativeSchema.Walker,
          Formata.JSONSchema,
          Formata.JSONPointer,
          :formata_yaml_constr,
          :formata_yaml_parser
        ] do
      assert module in modules
    end

    legacy_prefixes = [
      "Elixir.Formata.Jason",
      "Elixir.Formata.Toml",
      "Elixir.Formata.YamlElixir",
      "Elixir.Formata.Ymlr",
      "Elixir.Formata.Backplane",
      "Elixir.Formata.ExJSONPointer",
      "Elixir.Formata.Vendor",
      "formata_yamerl"
    ]

    for module <- modules do
      refute String.starts_with?(Atom.to_string(module), legacy_prefixes),
             "legacy backend module is still shipped: #{inspect(module)}"
    end
  end
end
