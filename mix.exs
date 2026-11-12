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

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:gsmlg_toml, "~> 1.0"},
      {:yaml_elixir, "~> 2.12"},
      # Called directly for single-document and duplicate-key checks.
      {:yamerl, "~> 0.10"},
      {:ymlr, "~> 5.1"},
      {:backplane_schema, "~> 1.10 and >= 1.10.76"},
      {:backplane_json_schema, "~> 1.10 and >= 1.10.76"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE NOTICE.md .formatter.exs docs)
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
        Schemas: [Formata.Schema, Formata.Schema.Native, Formata.Schema.JSONSchema],
        Support: [Formata.Transform, Formata.Error]
      ]
    ]
  end
end
