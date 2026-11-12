defmodule Formata.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/gsmlg-dev/formata"

  def project do
    [
      app: :formata,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: "Composable data codecs, schemas, and validation for Elixir.",
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Formata has no runtime dependencies: the codec and schema backends are
  # maintained forks under lib/formata/ and src/ (see NOTICE.md).
  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT", "Apache-2.0", "BSD-2-Clause"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files:
        ~w(lib src include mix.exs README.md CHANGELOG.md LICENSE LICENSES NOTICE.md .formatter.exs docs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "docs/design.md",
        "docs/release.md",
        "CHANGELOG.md",
        "NOTICE.md",
        "LICENSE"
      ],
      groups_for_modules: [
        Codecs: [Formata.Codec, Formata.Codec.JSON, Formata.Codec.TOML, Formata.Codec.YAML],
        Schemas: [
          Formata.Schema,
          Formata.Schema.Native,
          Formata.Schema.JSONSchema,
          Formata.Backplane.Schema,
          Formata.Backplane.Schema.Error
        ],
        Support: [Formata.Transform, Formata.Error]
      ],
      filter_modules: &public_module?/2
    ]
  end

  # Forked backends are internal, except the native schema vocabulary
  # (`Formata.Backplane.Schema`) that callers use to define schemas.
  @internal ~w(Jason Toml YamlElixir Ymlr ExJSONPointer Backplane)
  defp public_module?(module, _metadata) do
    case Module.split(module) do
      ["Formata", "Backplane", "Schema"] -> true
      ["Formata", "Backplane", "Schema", "Error"] -> true
      ["Formata", name | _] -> name not in @internal
      _ -> true
    end
  end
end
