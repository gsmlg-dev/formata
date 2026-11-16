defmodule Formata.MixProject do
  use Mix.Project

  @version "0.3.3"
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
        "docs/toml-correctness-review.md",
        "docs/yaml-correctness-review.md",
        "docs/release.md",
        "CHANGELOG.md",
        "NOTICE.md",
        "LICENSE"
      ],
      groups_for_modules: [
        Codecs: [
          Formata.Codec,
          Formata.Codec.JSON,
          Formata.Codec.JSON.Stream,
          Formata.Codec.JSON5,
          Formata.Codec.TOML,
          Formata.Codec.YAML
        ],
        Schemas: [
          Formata.Schema,
          Formata.Schema.Native,
          Formata.Schema.JSONSchema,
          Formata.NativeSchema,
          Formata.NativeSchema.Error,
          Formata.NativeSchema.Walker
        ],
        Support: [Formata.JSON, Formata.Transform, Formata.Error]
      ],
      filter_modules: &public_module?/2,
      skip_code_autolink_to: &internal_reference?/1
    ]
  end

  # Mentions of internal fork modules stay plain code text in the docs.
  @internal_ref ~r/^(?:[tc]:)?Formata\.(?:JSON\.Backend\b|TOML\b|YAML\b|JSONPointer\b|JSONSchema\b|NativeSchema\.(?!(?:Error|Walker)\b)[A-Z])/
  defp internal_reference?(term), do: Regex.match?(@internal_ref, term)

  # Forked backends are internal, except the native schema vocabulary
  # (`Formata.NativeSchema`) that callers use to define schemas.
  @internal ~w(TOML YAML JSONPointer JSONSchema NativeSchema)
  defp public_module?(module, _metadata) do
    case Module.split(module) do
      ["Formata", "NativeSchema"] -> true
      ["Formata", "NativeSchema", "Error"] -> true
      ["Formata", "NativeSchema", "Walker"] -> true
      ["Formata", "JSON", "Backend" | _] -> false
      ["Formata", name | _] -> name not in @internal
      _ -> true
    end
  end
end
