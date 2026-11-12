defmodule Formata do
  @moduledoc """
  Composable data codecs, schemas, and validation for Elixir.

  Formata decodes and encodes JSON, TOML, and YAML, validates data against
  native (`Backplane.Schema`) schemas or JSON Schema documents
  (`Backplane.JsonSchema`), and applies explicit transformations.

      iex> {:ok, schema} = Formata.Schema.native(%{"port" => {:required, {:integer, gte: 1}}})
      iex> {:ok, data} = Formata.decode(~s({"port": 8080}), :json)
      iex> Formata.validate(data, schema)
      :ok
      iex> Formata.encode(data, :toml)
      {:ok, "port = 8080\\n"}

  ## Conventions

    * Data-first arguments: `decode(input, format)`, `encode(data, format)`,
      `convert(input, from, to)`, `validate(data, schema)`, `cast(data, schema)`.
    * Producing operations return `{:ok, result}`; `validate/3` returns `:ok`.
    * Expected failures return `{:error, errors}` with a non-empty list of
      `Formata.Error` structs.
  """

  alias Formata.Codec
  alias Formata.Error
  alias Formata.Schema

  @type format :: Codec.format()
  @type errors :: [Error.t(), ...]

  @doc """
  Decodes a document.

  `format` is `:json`, `:toml`, `:yaml`, or a `Formata.Codec` module; `opts`
  are passed to the codec.

      iex> Formata.decode("name: Ada", :yaml)
      {:ok, %{"name" => "Ada"}}

      iex> {:error, [%Formata.Error{kind: :parse, code: :syntax}]} = Formata.decode("{", :json)
  """
  @spec decode(binary, format, keyword) :: {:ok, term} | {:error, errors}
  def decode(input, format, opts \\ []) when is_binary(input) and is_list(opts) do
    with {:ok, codec} <- Codec.fetch(format), do: codec.decode(input, opts)
  end

  @doc """
  Encodes data as a document.

  Values the target format cannot represent are rejected with `:encode` errors;
  nothing is dropped or converted implicitly.

      iex> Formata.encode(%{"a" => [1, 2]}, :json)
      {:ok, ~s({"a":[1,2]})}

      iex> {:error, [%Formata.Error{kind: :encode, code: :unrepresentable, path: ["a"]}]} =
      ...>   Formata.encode(%{"a" => nil}, :toml)
  """
  @spec encode(term, format, keyword) :: {:ok, binary} | {:error, errors}
  def encode(data, format, opts \\ []) when is_list(opts) do
    with {:ok, codec} <- Codec.fetch(format), do: codec.encode(data, opts)
  end

  @doc """
  Converts a document from one format to another.

  The document is decoded into Elixir values, the optional `:transforms` are
  applied in order (see `Formata.Transform.apply_all/2`), and the result is
  encoded. No intermediate format is used.

  ## Options

    * `:transforms` - explicit transformations, for example `[:drop_nils]`
    * `:decode` - options for the source codec
    * `:encode` - options for the target codec

  ## Examples

      iex> Formata.convert(~s({"name": "Ada", "nick": null}), :json, :toml, transforms: [:drop_nils])
      {:ok, ~s(name = "Ada"\\n)}

      iex> {:error, [%Formata.Error{kind: :encode, code: :unrepresentable}]} =
      ...>   Formata.convert(~s({"nick": null}), :json, :toml)
  """
  @spec convert(binary, format, format, keyword) :: {:ok, binary} | {:error, errors}
  def convert(input, from, to, opts \\ []) when is_binary(input) and is_list(opts) do
    with {:ok, data} <- decode(input, from, Keyword.get(opts, :decode, [])),
         {:ok, data} <- Formata.Transform.apply_all(data, Keyword.get(opts, :transforms, [])) do
      encode(data, to, Keyword.get(opts, :encode, []))
    end
  end

  @doc """
  Validates data against a compiled schema without changing it.

  No coercion, defaults, or field stripping happen; the data is checked as
  given. Returns `:ok` or `{:error, errors}`.

  ## Options

    * `unknown: :allow | :reject` - native schemas only (default `:allow`).
      JSON Schemas accept no options; their own `additionalProperties` /
      `unevaluatedProperties` apply.

  ## Examples

      iex> {:ok, schema} = Formata.Schema.native(%{age: :integer})
      iex> Formata.validate(%{"age" => 30}, schema)
      :ok
      iex> {:error, [%Formata.Error{kind: :validation, code: :type, path: ["age"]}]} =
      ...>   Formata.validate(%{"age" => "30"}, schema)
  """
  @spec validate(term, Schema.t(), keyword) :: :ok | {:error, errors}
  def validate(data, schema, opts \\ [])

  def validate(data, %Schema{kind: :native} = schema, opts) when is_list(opts),
    do: Formata.Schema.Native.validate(schema, data, opts)

  def validate(data, %Schema{kind: :json_schema} = schema, opts) when is_list(opts),
    do: Formata.Schema.JSONSchema.validate(schema, data, opts)

  @doc """
  Validates and transforms data with a native schema.

  Applies the schema's defaults, coercions, and transforms, and handles unknown
  fields per `unknown: :strip | :allow | :reject` (default `:strip`). See
  `Formata.Schema.Native` for the order of operations. Returns `{:ok, data}`.

  JSON Schemas define no transformations, so casting with one returns an
  `:unsupported` error.

      iex> {:ok, schema} = Formata.Schema.native(%{"page" => {:coerce, :integer}})
      iex> Formata.cast(%{"page" => "2"}, schema)
      {:ok, %{"page" => 2}}
  """
  @spec cast(term, Schema.t(), keyword) :: {:ok, term} | {:error, errors}
  def cast(data, schema, opts \\ [])

  def cast(data, %Schema{kind: :native} = schema, opts) when is_list(opts),
    do: Formata.Schema.Native.cast(schema, data, opts)

  def cast(_data, %Schema{kind: :json_schema}, _opts) do
    Error.error(
      :unsupported,
      :cast_unsupported,
      "JSON Schemas define no transformations (annotations such as default are " <>
        "not applied); use Formata.validate/3, or a native schema for casting",
      backend: Formata.Schema.JSONSchema
    )
  end
end
