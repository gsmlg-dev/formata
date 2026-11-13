defmodule Formata.Error do
  @moduledoc """
  Structured error returned by every Formata operation.

  Expected failures are returned as `{:error, errors}` where `errors` is a
  non-empty list of `%Formata.Error{}` values.

  ## Fields

    * `:kind` - the failure class, one of:
      * `:parse` - a document could not be decoded
      * `:encode` - data could not be written in the target format
      * `:schema` - a schema definition is invalid or cannot be compiled/resolved
      * `:validation` - data does not satisfy a schema
      * `:transform` - an explicit transformation (`cast/3`, `Formata.Transform`) failed
      * `:unsupported` - the requested operation or option is not supported for
        this schema, format, or value
    * `:code` - a stable machine-readable atom (for example `:syntax`,
      `:duplicate_key`, `:unrepresentable`, `:type`, `:required`,
      `:unknown_field`, `:oneOf`). Validation codes are taken from the backend
      (`Formata.Backplane.Schema.Error.code` for native schemas,
      `Formata.Backplane.JsonSchema.Types.Error.rule` for JSON Schema).
    * `:message` - a human-readable message.
    * `:backend` - the module that produced or detected the failure
      (`Formata.Jason`, `Formata.Toml`, `Formata.YamlElixir`, `Formata.Ymlr`, `Formata.Backplane.Schema`,
      `Formata.Backplane.JsonSchema`, or a Formata module for checks Formata performs).
    * `:format` - the codec format (`:json`, `:json5`, `:toml`, `:yaml`) when relevant.
    * `:path` - the data path as a list of map keys and list indexes
      (`[]` is the root).
    * `:schema_path` - the schema location when it is known.
    * `:location` - `%{line: pos_integer, column: pos_integer}` and/or
      `%{offset: non_neg_integer}` only when the backend supplies them;
      otherwise `nil`. Formata never invents source positions.
    * `:details` - extra structured data (expected values, keywords, ...).
    * `:cause` - the original backend error term, when useful.
  """

  @type kind :: :parse | :encode | :schema | :validation | :transform | :unsupported
  @type path :: [term]
  @type location ::
          nil
          | %{
              optional(:line) => pos_integer,
              optional(:column) => pos_integer,
              optional(:offset) => non_neg_integer
            }

  @type t :: %__MODULE__{
          kind: kind,
          code: atom,
          message: String.t(),
          backend: module | nil,
          format: atom | nil,
          path: path,
          schema_path: path | nil,
          location: location,
          details: map,
          cause: term
        }

  defexception kind: nil,
               code: nil,
               message: nil,
               backend: nil,
               format: nil,
               path: [],
               schema_path: nil,
               location: nil,
               details: %{},
               cause: nil

  @kinds [:parse, :encode, :schema, :validation, :transform, :unsupported]

  @doc """
  Builds an error. `kind`, `code`, and `message` are required.
  """
  @spec new(kind, atom, String.t(), keyword) :: t
  def new(kind, code, message, fields \\ [])
      when kind in @kinds and is_atom(code) and is_binary(message) do
    struct!(__MODULE__, [kind: kind, code: code, message: message] ++ fields)
  end

  @doc """
  Wraps a single error as the `{:error, [error]}` result shape.
  """
  @spec error(kind, atom, String.t(), keyword) :: {:error, [t, ...]}
  def error(kind, code, message, fields \\ []), do: {:error, [new(kind, code, message, fields)]}

  @impl true
  def message(%__MODULE__{message: message, path: path}) do
    case path do
      [] -> message
      nil -> message
      path -> "at #{format_path(path)}: #{message}"
    end
  end

  @doc """
  Formats a data path as a JSON-Pointer-like string, for example `/users/0/name`.
  """
  @spec format_path(path) :: String.t()
  def format_path([]), do: "/"

  def format_path(path) when is_list(path) do
    Enum.map_join(path, fn segment -> "/" <> escape_segment(segment) end)
  end

  defp escape_segment(segment) when is_binary(segment),
    do: segment |> String.replace("~", "~0") |> String.replace("/", "~1")

  defp escape_segment(segment) when is_integer(segment) or is_atom(segment),
    do: to_string(segment)

  defp escape_segment(segment), do: inspect(segment)
end
