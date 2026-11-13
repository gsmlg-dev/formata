defmodule Formata.Codec.JSON5 do
  @moduledoc """
  JSON5 codec ([JSON5 1.0.0](https://spec.json5.org/)).

  JSON5 is a separate format, not a mode of `:json`: use
  `Formata.decode(input, :json5)` and `Formata.encode(data, :json5)`.

  ## Decoding

  The full JSON5 1.0.0 grammar is accepted:

    * `//` and `/* */` comments, and a trailing comma in arrays and objects
    * single- or double-quoted strings, with the ECMAScript 5.1 escapes
      (`\\v`, `\\0`, `\\xHH`, `\\uHHHH`, `\\'`, any other character escaping
      itself) and line continuations (a backslash before LF, CR, CRLF, U+2028,
      or U+2029); U+2028 and U+2029 may appear unescaped in strings
    * unquoted object keys that are ECMAScript 5.1 `IdentifierName`s,
      including Unicode letters and `\\uHHHH` escapes. Character classes come
      from the Unicode general-category tables of the runtime's PCRE library
      (a newer Unicode version than ES5.1 references)
    * the additional JSON5 whitespace (VT, FF, NBSP, BOM, U+2028, U+2029,
      and other `Zs` space separators)
    * numbers with a leading `+`, leading or trailing decimal point (`.5`,
      `5.`), hexadecimal integers (`0x1F`, `-0xff`), `Infinity`, `-Infinity`,
      `+Infinity`, and `NaN` (also `+NaN` / `-NaN`)

  Decoded values use the portable domain (see `Formata.Codec`):

    * object keys are strings (never atoms); duplicate keys, compared after
      unescaping (`{a: 1, "\\u0061": 2}`), are `:parse` / `:duplicate_key` errors
    * numbers without a fraction or exponent (decimal or hexadecimal) are
      integers, others are floats. `Infinity`, `-Infinity`, and `NaN` become
      `:infinity`, `:negative_infinity`, and `:nan`. The sign of `NaN` is not
      kept. `-0` is the integer `0`, while `-0.0` stays the float `-0.0`
    * a finite literal outside the float range (`1e400`) is a `:parse` /
      `:syntax` error; it never becomes `Infinity`. Integers are limited to
      1024 digits, like `:json`
    * a `\\u` escape of an unpaired UTF-16 surrogate cannot be represented in
      a UTF-8 string and is a `:syntax` error

  Errors carry the byte offset and the line/column derived from it (lines
  are counted by LF). JSON5 decoding takes no options: comments and trailing
  commas are always allowed, so `:comments` and `:trailing_commas` are
  rejected as `:invalid_option`.

  ## Encoding

  The output is deterministic and minimal: the JSON subset of JSON5, with
  object keys sorted and quoted, plus `Infinity`, `-Infinity`, and `NaN` for
  `:infinity`, `:negative_infinity`, and `:nan`. No comments, unquoted keys,
  or trailing commas are produced. The domain is the JSON domain plus those
  three values; everything else is rejected with `:encode` errors.

  Options:

    * `:pretty` - indent with two spaces (default `false`)

  ## Conversions

  `Formata.convert(input, :json5, :json)` works for data inside the JSON
  domain. Non-finite numbers are rejected by the JSON encoder with
  `:unrepresentable` errors at their path; replace them explicitly (for
  example `transforms: [:special_floats_to_strings]`) when that loss is
  acceptable. JSON Schema validation likewise rejects them as
  `:non_json_value`.
  """

  @behaviour Formata.Codec

  alias Formata.Codec.JSON5.Parser
  alias Formata.Error

  @impl true
  def format, do: :json5

  @impl true
  def decode(input, opts \\ [])

  def decode(input, opts) when is_binary(input) and is_list(opts) do
    with :ok <- Formata.Codec.check_options(opts, [], backend: __MODULE__, format: :json5) do
      case Parser.parse(input) do
        {:ok, value} ->
          {:ok, value}

        {:error, code, message, offset, details} ->
          {path, details} = Map.pop(details, :path, [])

          Error.error(:parse, code, message,
            backend: __MODULE__,
            format: :json5,
            path: path,
            location: Formata.Codec.offset_location(input, offset),
            details: details
          )
      end
    end
  end

  @profile %{
    format: :json5,
    backend: __MODULE__,
    null: true,
    special_floats: true,
    temporal: false,
    key?: &is_binary/1,
    key_hint: "JSON5 object keys must be strings (see Formata.Transform.stringify_keys/1)"
  }

  @impl true
  def encode(data, opts \\ []) when is_list(opts) do
    with :ok <-
           Formata.Codec.check_options(opts, [{:pretty, &is_boolean/1, "a boolean"}],
             backend: __MODULE__,
             format: :json5
           ),
         :ok <- Formata.Codec.check_domain(data, @profile) do
      indent = if Keyword.get(opts, :pretty, false), do: "", else: nil
      {:ok, IO.iodata_to_binary(value(data, indent))}
    end
  end

  # `indent` is nil for compact output, or the current indentation.
  defp value(nil, _indent), do: "null"
  defp value(true, _indent), do: "true"
  defp value(false, _indent), do: "false"
  defp value(:infinity, _indent), do: "Infinity"
  defp value(:negative_infinity, _indent), do: "-Infinity"
  defp value(:nan, _indent), do: "NaN"
  defp value(v, _indent) when is_integer(v), do: Integer.to_string(v)
  defp value(v, _indent) when is_float(v) or is_binary(v), do: Formata.Jason.encode_to_iodata!(v)
  defp value([], _indent), do: "[]"
  defp value(map, _indent) when map_size(map) == 0, do: "{}"

  defp value(list, indent) when is_list(list),
    do: container("[", "]", Enum.map(list, &value(&1, deeper(indent))), indent)

  defp value(map, indent) when is_map(map) do
    sep = if indent, do: ": ", else: ":"

    members =
      map
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {k, v} ->
        [Formata.Jason.encode_to_iodata!(k), sep, value(v, deeper(indent))]
      end)

    container("{", "}", members, indent)
  end

  defp container(open, close, items, nil), do: [open, Enum.intersperse(items, ","), close]

  defp container(open, close, items, indent) do
    inner = "\n" <> deeper(indent)
    [open, inner, Enum.intersperse(items, ["," | inner]), "\n", indent, close]
  end

  defp deeper(nil), do: nil
  defp deeper(indent), do: indent <> "  "
end
