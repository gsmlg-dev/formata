defmodule Formata.Schema do
  @moduledoc """
  Schema creation, checking, and compiled-schema metadata.

  Formata keeps two independent schema systems:

    * `:native` - `Backplane.Schema` definitions (Elixir data). See
      `Formata.Schema.Native`.
    * `:json_schema` - JSON Schema documents (Draft 7 or Draft 2020-12),
      compiled and validated by `Backplane.JsonSchema`. See
      `Formata.Schema.JSONSchema`.

  A JSON Schema document is never converted into a native schema, and native
  schemas are never exported to JSON Schema to validate data.

  ## Compiling

      iex> {:ok, schema} = Formata.Schema.compile(:native, %{name: {:required, :string}})
      iex> schema.kind
      :native

      iex> {:ok, schema} = Formata.Schema.compile(:json_schema, %{"type" => "integer"})
      iex> {schema.kind, schema.dialect}
      {:json_schema, :draft2020_12}

  A compiled `%Formata.Schema{}` is an immutable value: compile once, then pass
  it to `Formata.validate/3` and `Formata.cast/3` as often as needed.

  ## Fields

    * `:kind` - `:native` or `:json_schema`
    * `:dialect` - `:draft7` or `:draft2020_12` for JSON Schema, `nil` for native
    * `:backend` - `Backplane.Schema` or `Backplane.JsonSchema`
    * `:compiled` - the backend representation (the checked native definition or
      a `Backplane.JsonSchema.Types.Schema`)
    * `:source` - the definition/document as given
    * `:options` - the compile options
    * `:plans` - precomputed native execution plans (internal)
  """

  alias Formata.Error

  @type kind :: :native | :json_schema
  @type dialect :: :draft7 | :draft2020_12

  @type t :: %__MODULE__{
          kind: kind,
          dialect: dialect | nil,
          backend: module,
          compiled: term,
          source: term,
          options: keyword,
          plans: map | nil
        }

  @enforce_keys [:kind, :backend, :compiled, :source]
  defstruct [:kind, :dialect, :backend, :compiled, :source, options: [], plans: nil]

  @doc """
  Compiles a schema of the given kind.

  See `Formata.Schema.Native.compile/2` and `Formata.Schema.JSONSchema.compile/2`
  for the options of each kind.
  """
  @spec compile(kind, term, keyword) :: {:ok, t} | {:error, [Error.t(), ...]}
  def compile(kind, definition, opts \\ [])
  def compile(:native, definition, opts), do: Formata.Schema.Native.compile(definition, opts)

  def compile(:json_schema, document, opts),
    do: Formata.Schema.JSONSchema.compile(document, opts)

  def compile(kind, _definition, _opts) do
    Error.error(:unsupported, :unknown_schema_kind, "unknown schema kind #{inspect(kind)}",
      details: %{kind: kind, supported: [:native, :json_schema]}
    )
  end

  @doc """
  Checks a schema definition without keeping the compiled result.

  Returns `:ok` or `{:error, errors}` with `:schema` errors. Checking the
  definition is separate from validating data.

      iex> Formata.Schema.check(:native, %{age: :integer})
      :ok

      iex> {:error, [%Formata.Error{kind: :schema}]} = Formata.Schema.check(:native, %{age: :intger})
  """
  @spec check(kind, term, keyword) :: :ok | {:error, [Error.t(), ...]}
  def check(kind, definition, opts \\ []) do
    with {:ok, _schema} <- compile(kind, definition, opts), do: :ok
  end

  @doc "Shortcut for `compile(:native, definition, opts)`."
  @spec native(term, keyword) :: {:ok, t} | {:error, [Error.t(), ...]}
  def native(definition, opts \\ []), do: compile(:native, definition, opts)

  @doc "Shortcut for `compile(:json_schema, document, opts)`."
  @spec json_schema(map | boolean, keyword) :: {:ok, t} | {:error, [Error.t(), ...]}
  def json_schema(document, opts \\ []), do: compile(:json_schema, document, opts)
end
