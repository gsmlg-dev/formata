defmodule Formata.Codec.TOML.Encoder do
  # TODO(upstream): gsmlg-dev/gsmlg_umbrella#12 - adopt a published gsmlg_toml
  # encoder once it exists and passes this suite.
  @moduledoc """
  Focused TOML 1.0.0 encoder.

  `gsmlg_toml` 1.0.0 only decodes, so Formata ships this encoder.

  ## Domain

  | Elixir value                 | TOML                                  |
  | ---------------------------- | ------------------------------------- |
  | map with string keys (root)  | the document (root table)             |
  | nested map                   | `[table]` section (inline `{}` inside arrays) |
  | non-empty list of maps       | array of tables `[[name]]`            |
  | other list (incl. `[]`)      | inline array                          |
  | UTF-8 binary                 | basic string with escapes             |
  | integer in signed 64-bit range | integer                             |
  | float / `:infinity` / `:negative_infinity` / `:nan` | float / `inf` / `-inf` / `nan` |
  | `true` / `false`             | boolean                               |
  | `DateTime`                   | offset date-time                      |
  | `NaiveDateTime`              | local date-time                       |
  | `Date`                       | local date                            |
  | `Time`                       | local time                            |

  Everything else is rejected: a non-map root, `nil`, atoms, tuples, other
  structs, non-string or non-UTF-8 keys, integers outside the 64-bit range,
  years outside `0000..9999`, and `DateTime` offsets that are not whole minutes.
  Keys are emitted in sorted order; plain keys are bare when they match
  `[A-Za-z0-9_-]+` and quoted otherwise.
  """

  alias Formata.Error

  @int_min -9_223_372_036_854_775_808
  @int_max 9_223_372_036_854_775_807

  @profile %{
    format: :toml,
    backend: __MODULE__,
    null: false,
    special_floats: true,
    temporal: true,
    int_range: {@int_min, @int_max},
    key?: &is_binary/1,
    key_hint: "TOML keys must be strings (see Formata.Transform.stringify_keys/1)"
  }

  @doc """
  Encodes a map as a TOML document.

      iex> Formata.Codec.TOML.Encoder.encode(%{"title" => "x", "owner" => %{"name" => "Tom"}})
      {:ok, ~s(title = "x"\\n\\n[owner]\\nname = "Tom"\\n)}
  """
  @spec encode(term) :: {:ok, binary} | {:error, [Error.t(), ...]}
  def encode(data) when is_map(data) and not is_struct(data) do
    with :ok <- Formata.Codec.check_domain(data, @profile),
         :ok <- check_temporal(data, []) do
      {:ok, data |> table([], []) |> finish()}
    end
  end

  def encode(data) do
    Error.error(
      :encode,
      :invalid_root,
      "a TOML document must be a map (table), got: #{inspect(data, limit: 5)}",
      backend: __MODULE__,
      format: :toml,
      details: %{value: data}
    )
  end

  # -- Extra domain checks for temporal values ---------------------------------

  defp check_temporal(%struct{} = v, path) when struct in [Date, NaiveDateTime, DateTime] do
    cond do
      v.year < 0 or v.year > 9999 ->
        temporal_error(path, v, "year #{v.year} is outside 0000..9999")

      struct == DateTime and rem(v.utc_offset + v.std_offset, 60) != 0 ->
        temporal_error(path, v, "UTC offset is not a whole number of minutes")

      true ->
        :ok
    end
  end

  defp check_temporal(%_{}, _path), do: :ok

  defp check_temporal(v, path) when is_map(v) do
    Enum.reduce_while(v, :ok, fn {k, item}, :ok ->
      case check_temporal(item, [k | path]) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp check_temporal(v, path) when is_list(v) do
    v
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {item, i}, :ok ->
      case check_temporal(item, [i | path]) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp check_temporal(_v, _path), do: :ok

  defp temporal_error(path, v, message) do
    Error.error(:encode, :unrepresentable, "#{inspect(v)} cannot be represented: #{message}",
      backend: __MODULE__,
      format: :toml,
      path: Enum.reverse(path),
      details: %{value: v}
    )
  end

  # -- Document layout -----------------------------------------------------------

  # Returns a list of "blocks" (iodata); blocks are separated by blank lines.
  defp table(map, path, blocks) do
    entries = Enum.sort_by(map, fn {k, _} -> k end)

    {inline, sections} =
      Enum.split_with(entries, fn {_k, v} -> not table?(v) and not array_of_tables?(v) end)

    body = Enum.map(inline, fn {k, v} -> [key(k), " = ", value(v), "\n"] end)

    blocks =
      cond do
        path == [] and body == [] -> blocks
        path == [] -> [body | blocks]
        true -> [[header(path, "[", "]"), body] | blocks]
      end

    Enum.reduce(sections, blocks, fn
      {k, v}, blocks when is_map(v) ->
        table(v, path ++ [k], blocks)

      {k, items}, blocks ->
        Enum.reduce(items, blocks, fn item, blocks -> array_table(item, path ++ [k], blocks) end)
    end)
  end

  # An element of an array of tables: same as a table, but with a `[[...]]`
  # header that is always emitted (it creates the element).
  defp array_table(map, path, blocks) do
    entries = Enum.sort_by(map, fn {k, _} -> k end)

    {inline, sections} =
      Enum.split_with(entries, fn {_k, v} -> not table?(v) and not array_of_tables?(v) end)

    body = Enum.map(inline, fn {k, v} -> [key(k), " = ", value(v), "\n"] end)
    blocks = [[header(path, "[[", "]]"), body] | blocks]

    Enum.reduce(sections, blocks, fn
      {k, v}, blocks when is_map(v) ->
        table(v, path ++ [k], blocks)

      {k, items}, blocks ->
        Enum.reduce(items, blocks, fn item, blocks -> array_table(item, path ++ [k], blocks) end)
    end)
  end

  defp finish(blocks) do
    blocks
    |> Enum.reverse()
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
  end

  defp table?(v), do: is_map(v) and not is_struct(v)

  defp array_of_tables?([_ | _] = list), do: Enum.all?(list, &table?/1)
  defp array_of_tables?(_), do: false

  defp header(path, open, close), do: [open, Enum.map_intersperse(path, ".", &key/1), close, "\n"]

  # -- Keys and values ----------------------------------------------------------------

  defp key(k) do
    if k != "" and bare_key?(k), do: k, else: string(k)
  end

  defp bare_key?(<<>>), do: true

  defp bare_key?(<<c, rest::binary>>)
       when c in ?A..?Z or c in ?a..?z or c in ?0..?9 or c == ?_ or c == ?-,
       do: bare_key?(rest)

  defp bare_key?(_), do: false

  defp value(v) when is_binary(v), do: string(v)
  defp value(true), do: "true"
  defp value(false), do: "false"
  defp value(v) when is_integer(v), do: Integer.to_string(v)
  defp value(v) when is_float(v), do: float(v)
  defp value(:infinity), do: "inf"
  defp value(:negative_infinity), do: "-inf"
  defp value(:nan), do: "nan"
  defp value(%Date{} = v), do: Date.to_iso8601(v)
  defp value(%Time{} = v), do: Time.to_iso8601(v)
  defp value(%NaiveDateTime{} = v), do: NaiveDateTime.to_iso8601(v)
  defp value(%DateTime{} = v), do: DateTime.to_iso8601(v)
  defp value([]), do: "[]"
  defp value(list) when is_list(list), do: ["[", Enum.map_intersperse(list, ", ", &value/1), "]"]
  defp value(map) when map == %{}, do: "{}"

  defp value(map) when is_map(map) do
    pairs =
      map
      |> Enum.sort_by(fn {k, _} -> k end)
      |> Enum.map_intersperse(", ", fn {k, v} -> [key(k), " = ", value(v)] end)

    ["{ ", pairs, " }"]
  end

  # Erlang's shortest round-trip representation is always a valid TOML float
  # once it contains a fraction or exponent (e.g. "1.0", "1.0e-10", "-0.0").
  defp float(v), do: Float.to_string(v)

  defp string(s), do: [?", escape(s, []), ?"]

  defp escape(<<>>, acc), do: Enum.reverse(acc)
  defp escape(<<?", rest::binary>>, acc), do: escape(rest, ["\\\"" | acc])
  defp escape(<<?\\, rest::binary>>, acc), do: escape(rest, ["\\\\" | acc])
  defp escape(<<?\b, rest::binary>>, acc), do: escape(rest, ["\\b" | acc])
  defp escape(<<?\t, rest::binary>>, acc), do: escape(rest, ["\\t" | acc])
  defp escape(<<?\n, rest::binary>>, acc), do: escape(rest, ["\\n" | acc])
  defp escape(<<?\f, rest::binary>>, acc), do: escape(rest, ["\\f" | acc])
  defp escape(<<?\r, rest::binary>>, acc), do: escape(rest, ["\\r" | acc])

  defp escape(<<c, rest::binary>>, acc) when c < 0x20 or c == 0x7F do
    hex = c |> Integer.to_string(16) |> String.pad_leading(4, "0")
    escape(rest, ["\\u" <> hex | acc])
  end

  defp escape(<<c::utf8, rest::binary>>, acc), do: escape(rest, [<<c::utf8>> | acc])
end
