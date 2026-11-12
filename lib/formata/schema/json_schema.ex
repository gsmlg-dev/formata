defmodule Formata.Schema.JSONSchema do
  @moduledoc """
  JSON Schema documents compiled and validated by `Backplane.JsonSchema`.

  Documents are JSON-compatible maps (string keys) or the boolean schemas
  `true`/`false`. They are handed to `Backplane.JsonSchema` as they are; Formata
  never converts them to native schemas.

  ## Dialects

  Draft 2020-12 and Draft 7 are supported.

    * A recognized root `$schema` selects the dialect:
      `https://json-schema.org/draft/2020-12/schema` or
      `http://json-schema.org/draft-07/schema#`.
    * `dialect: :draft7 | :draft2020_12` selects it explicitly. Conflicting with
      the document's `$schema` is a `:schema` / `:dialect_conflict` error.
    * Without either, Draft 2020-12 is used.
    * A `$schema` that is not one of the recognized meta-schemas is rejected
      (`:schema` / `:unknown_dialect`) unless `dialect:` is given or a `:loader`
      is provided to resolve the custom meta-schema and its vocabularies.

  Unknown keywords and extension keywords (for example `x-*`) are accepted as
  annotations, as the dialects permit.

  ## Format assertion

  `format` is an annotation by default and does not reject data.
  Pass `format_assertion: true` to assert the formats implemented by
  `Backplane.JsonSchema` (`email`, `date-time`, `date`, `time`, `uri`, `ipv4`,
  `ipv6`, `hostname`, `regex`, `uuid`, ...). Unknown format names are always
  accepted. In Draft 2020-12, a custom meta-schema that enables the
  format-assertion vocabulary also enables assertion.

  ## References

  Local references (`#/$defs/...`, `#anchor`, embedded `$id` resources) are
  resolved without any I/O. Remote references are only loaded through an
  explicit `:loader` function `(uri -> {:ok, map | boolean} | {:error, term})`;
  Formata performs no network access. A reference that cannot be resolved fails
  validation with a `:schema` / `:unresolved_ref` error, never a silent pass.

  ## Defaults and other annotations

  `default`, `examples`, `title`, and other annotations never modify data.
  `Formata.cast/3` is not available for JSON Schemas because they define no
  transformations.

  ## Data model

  Data must be in the JSON data model: `nil`, booleans, numbers, strings,
  lists, and maps with string keys. Other terms (atom keys, `Date`, tuples,
  special-float atoms, ...) are reported as `:unsupported` / `:non_json_value`;
  convert them explicitly first (see `Formata.Transform`).

  Additional properties are governed only by the document
  (`additionalProperties`, `unevaluatedProperties`); there is no facade option
  that overrides them.
  """

  alias Formata.Error
  alias Formata.Schema

  @draft2020_12_uri "https://json-schema.org/draft/2020-12/schema"

  @dialects %{draft7: "draft7", draft2020_12: "draft2020_12"}

  @compile_opts [:dialect, :format_assertion, :content_assertion, :loader, :base_uri]

  @doc """
  Compiles a JSON Schema document.

  ## Options

    * `:dialect` - `:draft7` or `:draft2020_12`
    * `:format_assertion` - assert `format` (default `false`)
    * `:content_assertion` - assert `contentEncoding`/`contentMediaType`/`contentSchema`
      (default `false`)
    * `:loader` - `(uri -> {:ok, schema} | {:error, term})` for remote references
      and custom meta-schemas
    * `:base_uri` - base URI for resolving relative references
  """
  @spec compile(map | boolean, keyword) :: {:ok, Schema.t()} | {:error, [Error.t(), ...]}
  def compile(document, opts \\ []) when is_list(opts) do
    opts = Keyword.validate!(opts, @compile_opts)

    with :ok <- check_document(document),
         {:ok, backend_opts} <- backend_opts(opts),
         :ok <- check_dialect(document, opts),
         {:ok, compiled} <- backend_compile(document, opts, backend_opts) do
      {:ok,
       %Schema{
         kind: :json_schema,
         dialect: dialect_atom(compiled.draft),
         backend: Backplane.JsonSchema,
         compiled: compiled,
         source: document,
         options: opts
       }}
    end
  end

  defp check_document(document) when is_boolean(document), do: :ok

  defp check_document(document) when is_map(document) and not is_struct(document) do
    case Formata.Codec.check_domain(document, json_profile(__MODULE__)) do
      :ok ->
        :ok

      {:error, errors} ->
        {:error,
         Enum.map(errors, fn error ->
           %{
             error
             | kind: :schema,
               code: :invalid_schema,
               schema_path: error.path,
               path: [],
               message: "schema document is not JSON-compatible: " <> error.message
           }
         end)}
    end
  end

  defp check_document(document) do
    Error.error(
      :schema,
      :invalid_schema,
      "a JSON Schema must be a map or a boolean, got: #{inspect(document, limit: 5)}",
      backend: __MODULE__
    )
  end

  defp backend_opts(opts) do
    base =
      opts
      |> Keyword.take([:format_assertion, :content_assertion, :loader, :base_uri])
      |> Keyword.put_new(:format_assertion, false)
      |> Keyword.put_new(:content_assertion, false)

    case Keyword.fetch(opts, :dialect) do
      :error ->
        {:ok, base}

      {:ok, dialect} when is_map_key(@dialects, dialect) ->
        {:ok, Keyword.put(base, :draft, Map.fetch!(@dialects, dialect))}

      {:ok, other} ->
        Error.error(
          :unsupported,
          :unknown_dialect,
          "unsupported JSON Schema dialect #{inspect(other)}; expected :draft7 or :draft2020_12",
          backend: __MODULE__,
          details: %{dialect: other}
        )
    end
  end

  defp check_dialect(%{"$schema" => uri} = document, opts) when is_binary(uri) do
    known? =
      Backplane.JsonSchema.Draft7.Dialect.builtin_schema?(document) or
        Backplane.JsonSchema.Draft202012.Dialect.builtin_schema?(document)

    if known? or Keyword.has_key?(opts, :dialect) or is_function(opts[:loader], 1) do
      :ok
    else
      Error.error(
        :schema,
        :unknown_dialect,
        "unrecognized $schema #{inspect(uri)}; pass dialect: :draft7 | :draft2020_12, " <>
          "or a :loader that resolves the meta-schema",
        backend: __MODULE__,
        schema_path: ["$schema"],
        details: %{uri: uri}
      )
    end
  end

  defp check_dialect(_document, _opts), do: :ok

  defp backend_compile(document, opts, backend_opts) do
    case Backplane.JsonSchema.compile(prepare(document, opts), backend_opts) do
      {:ok, compiled} -> {:ok, compiled}
      {:error, error} -> {:error, [compile_error(error)]}
    end
  end

  # WORKAROUND(upstream): gsmlg-opt/backplane#170 - without `$schema`,
  # Backplane.JsonSchema enables the Draft 2020-12 format-assertion vocabulary
  # even when `format_assertion: false`. Declaring the standard 2020-12
  # meta-schema (the same dialect the spec defaults to) restores annotation-only
  # `format`. Remove once the fix is released and the format tests pass without it.
  # TODO(upstream): gsmlg-opt/backplane#170
  defp prepare(document, opts) when is_map(document) do
    if not Map.has_key?(document, "$schema") and opts[:dialect] in [nil, :draft2020_12] do
      Map.put(document, "$schema", @draft2020_12_uri)
    else
      document
    end
  end

  defp prepare(document, _opts), do: document

  defp compile_error(%Backplane.JsonSchema.Types.Error{rule: rule} = error) do
    code =
      case rule do
        :draft_conflict -> :dialect_conflict
        nil -> :invalid_schema
        rule -> rule
      end

    Error.new(:schema, code, Backplane.JsonSchema.format_error(error),
      backend: Backplane.JsonSchema,
      schema_path: Enum.reverse(error.path || []),
      details: context_details(error),
      cause: error
    )
  end

  defp compile_error(other) do
    Error.new(:schema, :invalid_schema, "JSON Schema compilation failed: #{inspect(other)}",
      backend: Backplane.JsonSchema,
      cause: other
    )
  end

  defp dialect_atom("draft7"), do: :draft7
  defp dialect_atom("draft2020_12"), do: :draft2020_12

  @doc false
  @spec validate(Schema.t(), term, keyword) :: :ok | {:error, [Error.t(), ...]}
  def validate(%Schema{kind: :json_schema, compiled: compiled}, data, opts) do
    with :ok <- reject_facade_options(opts),
         :ok <- check_data(data) do
      case Backplane.JsonSchema.validate(compiled, data) do
        :ok -> :ok
        {:error, errors} -> {:error, Enum.map(errors, &validation_error/1)}
      end
    end
  end

  defp reject_facade_options([]), do: :ok

  defp reject_facade_options(opts) do
    Error.error(
      :unsupported,
      :invalid_option,
      "JSON Schema validation takes no options (got #{inspect(Keyword.keys(opts))}); " <>
        "additional properties are controlled by the schema document itself",
      backend: __MODULE__,
      details: %{options: Keyword.keys(opts)}
    )
  end

  defp check_data(data) do
    case Formata.Codec.check_domain(data, json_profile(__MODULE__)) do
      :ok ->
        :ok

      {:error, errors} ->
        {:error,
         Enum.map(errors, fn error ->
           %{
             error
             | kind: :unsupported,
               code: :non_json_value,
               format: nil,
               message:
                 "value is outside the JSON data model (" <>
                   error.message <> "); convert it explicitly before JSON Schema validation"
           }
         end)}
    end
  end

  defp validation_error(%Backplane.JsonSchema.Types.Error{} = error) do
    {kind, code} =
      case {error.rule, error.context} do
        {:ref, %{contrast: contrast}}
        when contrast in [
               "ref_not_found",
               "load_remote",
               "compile_remote",
               "invalid_loader_response"
             ] ->
          {:schema, :unresolved_ref}

        {rule, _} ->
          {:validation, rule}
      end

    Error.new(kind, code, message(error),
      backend: Backplane.JsonSchema,
      path: Enum.reverse(error.path || []),
      details: context_details(error),
      cause: error
    )
  end

  # WORKAROUND(upstream): gsmlg-opt/backplane#172 - format_error/1 renders
  # integer path segments as raw bytes in its "At /..." prefix. The message is
  # formatted without the path; Formata.Error renders the path itself.
  # Remove once fixed upstream (the message tests still pass).
  # TODO(upstream): gsmlg-opt/backplane#172
  defp message(error), do: Backplane.JsonSchema.format_error(%{error | path: []})

  defp context_details(%{context: nil}), do: %{}

  defp context_details(%{context: context}) do
    context
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp json_profile(backend) do
    %{
      format: nil,
      backend: backend,
      null: true,
      special_floats: false,
      temporal: false,
      key?: &is_binary/1,
      key_hint: "JSON object keys must be strings"
    }
  end
end
