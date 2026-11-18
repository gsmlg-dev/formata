defmodule Formata.Codec.JSON do
  @moduledoc """
  JSON codec backed by `Formata.JSON.Backend`.

  ## Decoding

    * Any JSON value may be the root (objects, arrays, and scalars).
    * Object keys stay strings.
    * Duplicate object keys are rejected with a `:parse` / `:duplicate_key`
      error (RFC 8259 leaves their meaning undefined; Formata does not pick one).
    * Numbers become integers or floats; numbers outside the float range are a
      syntax error reported by Formata.JSON.Backend.
    * Syntax errors carry the byte offset reported by Formata.JSON.Backend and the line/column
      derived from it.

  Options (both decode-only, independent, and `false` by default, so a plain
  `decode/2` is strict RFC 8259):

    * `:comments` - accept `//` line comments (to the end of the line) and
      `/* ... */` block comments (non-nesting, must be closed) wherever JSON
      allows whitespace. Comment-like text inside strings is string content.
      Positions in errors refer to the original input.
    * `:trailing_commas` - accept a single comma after the last element of a
      non-empty array or object (`[1, 2,]`, `{"a": 1,}`). Empty slots such as
      `[1,,2]`, `[,]`, `{,}`, or a doubled trailing comma are always rejected.

  This is the "JSONC" mode; there is no separate JSONC codec. For a `.jsonc`
  file use `Formata.decode(input, :json, comments: true, trailing_commas: true)`
  (or only the extensions the file format allows). Comments are not preserved.
  `#` comments and JSON5 syntax are not accepted; use `:json5` for JSON5.

  Unknown options and non-boolean values are rejected with `:unsupported` /
  `:invalid_option` errors.

  For incremental parsing of a single document arriving in chunks, see
  `Formata.Codec.JSON.Stream`.

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
    with :ok <- check_decode_options(opts) do
      Formata.JSON.Decoder.decode(input, opts)
    end
  end

  @decode_options [
    {:comments, &is_boolean/1, "a boolean"},
    {:trailing_commas, &is_boolean/1, "a boolean"}
  ]

  defp check_decode_options(opts),
    do: Formata.Codec.check_options(opts, @decode_options, backend: __MODULE__, format: :json)

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
      case Formata.JSON.Backend.encode(data, pretty: pretty) do
        {:ok, json} ->
          {:ok, json}

        {:error, error} ->
          Error.error(:encode, :backend, Exception.message(error),
            backend: Formata.JSON.Backend,
            format: :json,
            cause: error
          )
      end
    end
  end
end
