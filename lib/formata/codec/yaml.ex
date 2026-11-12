defmodule Formata.Codec.YAML do
  @moduledoc """
  Single-document YAML codec: decoding with `Formata.YamlElixir` (yamerl), encoding
  with `Formata.Ymlr`.

  ## Decoding

    * Exactly one document is accepted. A stream containing more than one
      document is rejected with `:parse` / `:multiple_documents`; Formata
      never silently picks one. An empty stream decodes to `nil`.
    * Mapping keys stay as decoded (strings for plain keys; YAML integer or
      boolean keys stay integers/booleans). No atoms are created from content.
    * Duplicate mapping keys are rejected with `:parse` / `:duplicate_key`,
      including the line/column reported by yamerl.
    * Merge keys (`<<`) are rejected with `:unsupported` / `:merge_key`.
    * Anchors and aliases are expanded; anchors, comments, formatting and key
      order are not preserved.
    * `.inf`, `-.inf`, `.nan` become `:infinity`, `:negative_infinity`, `:nan`.
    * Timestamps are not resolved by the YAML core schema used by yamerl:
      `2001-12-14` decodes as the string `"2001-12-14"`.
    * Syntax errors carry the line/column reported by yamerl.

  Options: none.

  ## Encoding

  The YAML domain is `nil`, booleans, integers, floats (including the
  special-float atoms), UTF-8 strings, lists, and maps whose keys are strings,
  integers, or booleans. `Date`/`Time`/`DateTime` values are rejected because
  they do not decode back to the same values; convert them explicitly with
  `Formata.Transform.temporal_to_iso8601/1`.

  Every encoded document is decoded again and compared with the input. If the
  emitted YAML would read back as a different value (for example a string that
  the emitter left unquoted although it resolves to a number), encoding fails
  with `:encode` / `:roundtrip_mismatch` instead of returning lossy output.
  """

  @behaviour Formata.Codec

  alias Formata.Error

  @impl true
  def format, do: :yaml

  @impl true
  def decode(input, opts \\ [])

  def decode(input, opts) when is_binary(input) and is_list(opts) do
    case Formata.YamlElixir.read_all_from_string(input) do
      {:ok, []} ->
        {:ok, nil}

      {:ok, [document]} ->
        with {:ok, root} <- check_structure(input) do
          # Formata.YamlElixir maps a null document root to %{}; keep it null.
          if match?({:formata_yamerl_null, _, _, _}, root),
            do: {:ok, nil},
            else: {:ok, normalize(document)}
        end

      {:ok, documents} ->
        Error.error(
          :parse,
          :multiple_documents,
          "expected a single YAML document, found #{length(documents)}",
          backend: Formata.YamlElixir,
          format: :yaml,
          details: %{count: length(documents)}
        )

      {:error, %Formata.YamlElixir.ParsingError{} = error} ->
        Error.error(:parse, :syntax, error.message || "malformed YAML",
          backend: Formata.YamlElixir,
          format: :yaml,
          location: location(error.line, error.column),
          details: %{type: error.type},
          cause: error
        )

      {:error, error} ->
        Error.error(:parse, :syntax, Exception.message(error),
          backend: Formata.YamlElixir,
          format: :yaml,
          cause: error
        )
    end
  end

  defp location(line, column) when is_integer(line) and is_integer(column),
    do: %{line: line, column: column}

  defp location(line, _) when is_integer(line), do: %{line: line}
  defp location(_, _), do: nil

  defp normalize(:"+inf"), do: :infinity
  defp normalize(:"-inf"), do: :negative_infinity
  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)

  defp normalize(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {normalize(k), normalize(v)} end)

  defp normalize(value), do: value

  # Formata.YamlElixir folds duplicate keys (first wins) and rewrites `<<` keys, so the
  # detailed yamerl node tree is inspected for those before values are used.
  defp check_structure(input) do
    nodes =
      :formata_yamerl_constr.string(input,
        detailed_constr: true,
        keep_duplicate_keys: true,
        str_node_as_binary: true
      )

    [{:formata_yamerl_doc, root}] = nodes

    with :ok <- check_node(root, []), do: {:ok, root}
  end

  defp check_node({:formata_yamerl_map, _module, _tag, _loc, pairs}, path) do
    Enum.reduce_while(pairs, {:ok, MapSet.new()}, fn {key, value}, {:ok, seen} ->
      key_value = node_value(key)
      loc = node_loc(key)

      cond do
        key_value == "<<" ->
          {:halt,
           Error.error(:unsupported, :merge_key, "YAML merge keys (<<) are not supported",
             backend: __MODULE__,
             format: :yaml,
             path: Enum.reverse(path),
             location: loc
           )}

        MapSet.member?(seen, key_value) ->
          {:halt,
           Error.error(:parse, :duplicate_key, "duplicate mapping key #{inspect(key_value)}",
             backend: Formata.YamlElixir,
             format: :yaml,
             path: Enum.reverse(path),
             location: loc,
             details: %{key: key_value}
           )}

        true ->
          case check_node(value, [key_value | path]) do
            :ok -> {:cont, {:ok, MapSet.put(seen, key_value)}}
            error -> {:halt, error}
          end
      end
    end)
    |> case do
      {:ok, _seen} -> :ok
      error -> error
    end
  end

  defp check_node({:formata_yamerl_seq, _module, _tag, _loc, items, _count}, path) do
    items
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {item, i}, :ok ->
      case check_node(item, [i | path]) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp check_node(_scalar, _path), do: :ok

  defp node_value({:formata_yamerl_map, _, _, _, pairs}),
    do: Map.new(pairs, fn {k, v} -> {node_value(k), node_value(v)} end)

  defp node_value({:formata_yamerl_seq, _, _, _, items, _}), do: Enum.map(items, &node_value/1)
  defp node_value({:formata_yamerl_null, _, _, _}), do: nil
  defp node_value({_type, _module, _tag, _loc, value}), do: value
  defp node_value(other), do: other

  defp node_loc(node) when is_tuple(node) and tuple_size(node) >= 4 do
    case elem(node, 3) do
      loc when is_list(loc) -> location(loc[:line], loc[:column])
      _ -> nil
    end
  end

  defp node_loc(_), do: nil

  # -- Encoding -------------------------------------------------------------------

  @profile %{
    format: :yaml,
    backend: __MODULE__,
    null: true,
    special_floats: true,
    temporal: false,
    key?: &__MODULE__.valid_key?/1,
    key_hint: "YAML keys must be strings, integers, or booleans"
  }

  @doc false
  def valid_key?(key), do: is_binary(key) or is_integer(key) or is_boolean(key)

  @impl true
  def encode(data, opts \\ []) when is_list(opts) do
    with :ok <- Formata.Codec.check_domain(data, @profile),
         {:ok, yaml} <- emit(data),
         :ok <- verify(yaml, data) do
      {:ok, yaml}
    end
  end

  defp emit(data) do
    case Formata.Ymlr.document(to_ymlr(data)) do
      {:ok, yaml} ->
        {:ok, yaml}

      {:error, reason} ->
        Error.error(:encode, :backend, "Formata.Ymlr failed to encode: #{inspect(reason)}",
          backend: Formata.Ymlr,
          format: :yaml,
          cause: reason
        )
    end
  end

  # Formata.Ymlr spells special floats as these atoms.
  defp to_ymlr(:infinity), do: :inf
  defp to_ymlr(:negative_infinity), do: :"-inf"
  defp to_ymlr(list) when is_list(list), do: Enum.map(list, &to_ymlr/1)
  defp to_ymlr(map) when is_map(map), do: Map.new(map, fn {k, v} -> {k, to_ymlr(v)} end)
  defp to_ymlr(value), do: value

  defp verify(yaml, data) do
    case decode(yaml) do
      {:ok, ^data} ->
        :ok

      {:ok, decoded} ->
        path = first_difference(data, decoded, [])

        Error.error(
          :encode,
          :roundtrip_mismatch,
          "the YAML emitter produced output that reads back as a different value",
          backend: Formata.Ymlr,
          format: :yaml,
          path: path,
          details: %{expected: get_path(data, path), actual: get_path(decoded, path)}
        )

      {:error, errors} ->
        Error.error(:encode, :roundtrip_mismatch, "the YAML emitter produced unreadable output",
          backend: Formata.Ymlr,
          format: :yaml,
          cause: errors
        )
    end
  end

  defp first_difference(a, b, path) when is_map(a) and is_map(b) do
    Enum.find_value(Enum.sort_by(a, fn {k, _} -> k end), Enum.reverse(path), fn {k, v} ->
      if Map.has_key?(b, k) and Map.fetch!(b, k) === v,
        do: nil,
        else: first_difference(v, Map.get(b, k), [k | path])
    end)
  end

  defp first_difference(a, b, path) when is_list(a) and is_list(b) and length(a) == length(b) do
    a
    |> Enum.zip(b)
    |> Enum.with_index()
    |> Enum.find_value(Enum.reverse(path), fn {{x, y}, i} ->
      if x === y, do: nil, else: first_difference(x, y, [i | path])
    end)
  end

  defp first_difference(_a, _b, path), do: Enum.reverse(path)

  defp get_path(data, []), do: data
  defp get_path(data, [k | rest]) when is_map(data), do: get_path(Map.get(data, k), rest)

  defp get_path(data, [i | rest]) when is_list(data) and is_integer(i),
    do: get_path(Enum.at(data, i), rest)

  defp get_path(_data, _path), do: nil
end
