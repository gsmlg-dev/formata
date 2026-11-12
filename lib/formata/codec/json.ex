defmodule Formata.Codec.JSON do
  @moduledoc """
  JSON codec backed by `Jason`.

  ## Decoding

    * Any JSON value may be the root (objects, arrays, and scalars).
    * Object keys stay strings.
    * Duplicate object keys are rejected with a `:parse` / `:duplicate_key`
      error (RFC 8259 leaves their meaning undefined; Formata does not pick one).
    * Numbers become integers or floats; numbers outside the float range are a
      syntax error reported by Jason.
    * Syntax errors carry the byte offset reported by Jason and the line/column
      derived from it.

  Options: none.

  ## Encoding

  The JSON domain is `nil`, booleans, integers, finite floats, UTF-8 strings,
  lists, and maps with string keys. Atom keys, `Date`/`DateTime` values,
  `:infinity`/`:nan`, tuples, and other terms are rejected; convert them
  explicitly with `Formata.Transform`.

  Options:

    * `:pretty` - pretty-print the output (default `false`).
  """

  @behaviour Formata.Codec

  alias Formata.Error

  @impl true
  def format, do: :json

  @impl true
  def decode(input, opts \\ [])

  def decode(input, opts) when is_binary(input) and is_list(opts) do
    case Jason.decode(input, objects: :ordered_objects) do
      {:ok, value} ->
        case unorder(value, []) do
          {:ok, data} -> {:ok, data}
          {:error, error} -> {:error, [error]}
        end

      {:error, %Jason.DecodeError{position: position} = error} ->
        Error.error(:parse, :syntax, Exception.message(error),
          backend: Jason,
          format: :json,
          location: Formata.Codec.offset_location(input, position),
          cause: error
        )
    end
  end

  defp unorder(%Jason.OrderedObject{values: pairs}, path) do
    Enum.reduce_while(pairs, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      if Map.has_key?(acc, key) do
        {:halt,
         {:error,
          Error.new(:parse, :duplicate_key, "duplicate object key #{inspect(key)}",
            backend: Jason,
            format: :json,
            path: Enum.reverse(path),
            details: %{key: key}
          )}}
      else
        case unorder(value, [key | path]) do
          {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
          error -> {:halt, error}
        end
      end
    end)
  end

  defp unorder(list, path) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item, i}, {:ok, acc} ->
      case unorder(item, [i | path]) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp unorder(value, _path), do: {:ok, value}

  @profile %{
    format: :json,
    backend: __MODULE__,
    null: true,
    special_floats: false,
    temporal: false,
    key?: &is_binary/1,
    key_hint: "JSON object keys must be strings (see Formata.Transform.stringify_keys/1)"
  }

  @impl true
  def encode(data, opts \\ []) when is_list(opts) do
    pretty = Keyword.get(opts, :pretty, false)

    with :ok <- Formata.Codec.check_domain(data, @profile) do
      case Jason.encode(data, pretty: pretty) do
        {:ok, json} ->
          {:ok, json}

        {:error, error} ->
          Error.error(:encode, :backend, Exception.message(error),
            backend: Jason,
            format: :json,
            cause: error
          )
      end
    end
  end
end
