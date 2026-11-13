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
    * Plain implicit merge keys (`<<`) are rejected with `:unsupported` /
      `:merge_key`; quoted or explicitly string-tagged `<<` keys stay literal.
    * Null and float scalar keys remain distinct values (including normalized
      special floats). Sequence/mapping keys are `:unsupported_key` errors.
    * Anchors and aliases are expanded; anchors, comments, formatting and key
      order are not preserved.
    * `.inf`, `-.inf`, `.nan` become `:infinity`, `:negative_infinity`, `:nan`.
    * Timestamps are not resolved by the YAML core schema used by yamerl:
      `2001-12-14` decodes as the string `"2001-12-14"`.
    * Syntax errors carry the line/column reported by yamerl.

  Options (also enforced for encoding and its read-back check):

    * `:max_depth` — non-negative maximum node depth (default `128`); root
      depth is zero and mapping keys, values and sequence elements add one.
    * `:max_nodes` — positive maximum expanded node count (default `100_000`),
      including mapping keys and every occurrence of an aliased subtree.

  Limits are finite and local to each call. Parsing stops before an alias
  exceeds a limit; validation, normalization and conversion share one bounded
  traversal. The parser also bounds pending syntax before construction. An
  explicit `%YAML 1.1` directive selects that schema; otherwise YAML 1.2 core
  scalar resolution applies. Timestamps remain strings in both schemas.

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

  @default_limits [max_depth: 128, max_nodes: 100_000]

  @impl true
  def decode(input, opts \\ [])

  def decode(input, opts) when is_binary(input) and is_list(opts) do
    with {:ok, limits} <- limits(opts),
         {:ok, documents} <- read_nodes(input, limits) do
      case documents do
        [] ->
          {:ok, nil}

        [{:formata_yamerl_doc, root}] ->
          with {:ok, value, _remaining} <- convert_node(root, [], 0, limits.max_nodes, limits) do
            {:ok, value}
          end

        documents ->
          Error.error(
            :parse,
            :multiple_documents,
            "expected a single YAML document, found #{length(documents)}",
            backend: Formata.YamlElixir,
            format: :yaml,
            details: %{count: length(documents)}
          )
      end
    end
  end

  defp limits(opts) do
    specs = [
      {:max_depth, &(is_integer(&1) and &1 >= 0), "a non-negative integer"},
      {:max_nodes, &(is_integer(&1) and &1 > 0), "a positive integer"}
    ]

    with :ok <- Formata.Codec.check_options(opts, specs, backend: __MODULE__, format: :yaml) do
      {:ok, @default_limits |> Keyword.merge(opts) |> Map.new()}
    end
  end

  defp read_nodes(input, limits) do
    opts = [
      max_depth: limits.max_depth,
      max_nodes: limits.max_nodes,
      max_documents: 1,
      # Protect pending implicit-key parser state before constructor callbacks.
      max_parser_depth: limits.max_depth + 1,
      max_parser_nodes: limits.max_nodes
    ]

    case Formata.YamlElixir.read_nodes_from_string(input, opts) do
      {:ok, nodes} ->
        {:ok, nodes}

      {:error, %Formata.YamlElixir.ParsingError{} = error} ->
        code =
          if error.type in [:limit_exceeded, :multiple_documents], do: error.type, else: :syntax

        details = public_limit_details(error.details)

        Error.error(:parse, code, error.message || "malformed YAML",
          backend: Formata.YamlElixir,
          format: :yaml,
          path: Map.get(error.details, :path, []),
          location: location(error.line, error.column),
          details: Map.put(details, :type, error.type),
          cause: error
        )
    end
  end

  # Parser collection depth is one-based; expose the same root-zero depth
  # contract as constructor aliases, conversion and encoder preflight.
  defp public_limit_details(%{phase: :parser, limit: :max_depth} = details),
    do: details |> Map.update!(:max, &(&1 - 1)) |> Map.update!(:actual, &(&1 - 1))

  defp public_limit_details(details), do: details

  defp location(line, column) when is_integer(line) and is_integer(column),
    do: %{line: line, column: column}

  defp location(line, _) when is_integer(line), do: %{line: line}
  defp location(_, _), do: nil

  # Validate, normalize and convert in one bounded traversal. No entry is put
  # into an ordinary map until its key and value have been checked; duplicate
  # identities use the normalized Elixir key, without stringifying its type.
  defp convert_node(node, path, depth, remaining, limits) do
    with :ok <- budget(:parse, path, depth, remaining, limits, node_loc(node)) do
      convert_value(node, path, depth, remaining - 1, limits)
    end
  end

  defp convert_value({:formata_yamerl_map, _, _, _, pairs}, path, depth, remaining, limits) do
    Enum.reduce_while(pairs, {:ok, [], MapSet.new(), remaining}, fn {key, value},
                                                                    {:ok, acc, seen, left} ->
      with :ok <- supported_key(key, path),
           {:ok, decoded_key, left} <- convert_node(key, path, depth + 1, left, limits),
           :ok <- unique_key(decoded_key, key, seen, path),
           {:ok, decoded_value, left} <-
             convert_node(value, [decoded_key | path], depth + 1, left, limits) do
        {:cont, {:ok, [{decoded_key, decoded_value} | acc], MapSet.put(seen, decoded_key), left}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, pairs, _seen, left} -> {:ok, Map.new(pairs), left}
      error -> error
    end
  end

  defp convert_value({:formata_yamerl_seq, _, _, _, items, _}, path, depth, remaining, limits) do
    items
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, [], remaining}, fn {item, index}, {:ok, acc, left} ->
      case convert_node(item, [index | path], depth + 1, left, limits) do
        {:ok, value, left} -> {:cont, {:ok, [value | acc], left}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items, left} -> {:ok, Enum.reverse(items), left}
      error -> error
    end
  end

  defp convert_value({:formata_yamerl_null, _, _, _}, _, _, remaining, _),
    do: {:ok, nil, remaining}

  defp convert_value({_type, _module, _tag, _loc, value}, _, _, remaining, _),
    do: {:ok, normalize_scalar(value), remaining}

  defp normalize_scalar(:"+inf"), do: :infinity
  defp normalize_scalar(:"-inf"), do: :negative_infinity
  defp normalize_scalar(value), do: value

  defp supported_key({type, _, _, _, _} = key, path)
       when type == :formata_yamerl_map do
    unsupported_key(key, path, :mapping)
  end

  defp supported_key({:formata_yamerl_seq, _, _, _, _, _} = key, path),
    do: unsupported_key(key, path, :sequence)

  defp supported_key({:formata_yamerl_str, _, _, pres, "<<"} = key, path) do
    if pres[:scalar_style] == :plain and pres[:source_tag] == {:non_specific, ~c"?"} do
      Error.error(:unsupported, :merge_key, "YAML merge keys (<<) are not supported",
        backend: __MODULE__,
        format: :yaml,
        path: Enum.reverse(path),
        location: node_loc(key)
      )
    else
      :ok
    end
  end

  defp supported_key(_key, _path), do: :ok

  defp unsupported_key(key, path, type) do
    Error.error(:unsupported, :unsupported_key, "YAML #{type} keys are not supported",
      backend: __MODULE__,
      format: :yaml,
      path: Enum.reverse(path),
      location: node_loc(key),
      details: %{type: type}
    )
  end

  defp unique_key(key, node, seen, path) do
    if MapSet.member?(seen, key) do
      Error.error(:parse, :duplicate_key, "duplicate mapping key #{inspect(key)}",
        backend: Formata.YamlElixir,
        format: :yaml,
        path: Enum.reverse(path),
        location: node_loc(node),
        details: %{key: key}
      )
    else
      :ok
    end
  end

  defp node_loc(node) when is_tuple(node) and tuple_size(node) >= 4 do
    case elem(node, 3) do
      loc when is_list(loc) -> location(loc[:line], loc[:column])
      _ -> nil
    end
  end

  defp budget(kind, path, depth, remaining, limits, location \\ nil) do
    cond do
      depth > limits.max_depth ->
        limit_error(kind, path, :max_depth, limits.max_depth, depth, location)

      remaining <= 0 ->
        limit_error(kind, path, :max_nodes, limits.max_nodes, limits.max_nodes + 1, location)

      true ->
        :ok
    end
  end

  defp limit_error(kind, path, limit, max, actual, location) do
    Error.error(kind, :limit_exceeded, "YAML #{limit} limit of #{max} exceeded",
      backend: __MODULE__,
      format: :yaml,
      path: Enum.reverse(path),
      location: location,
      details: %{limit: limit, max: max, actual: actual}
    )
  end

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
    with {:ok, limits} <- limits(opts),
         {:ok, _remaining} <- check_input_budget(data, [], 0, limits.max_nodes, limits),
         :ok <- Formata.Codec.check_domain(data, @profile),
         {:ok, yaml} <- emit(data),
         :ok <- verify(yaml, data, limits) do
      {:ok, yaml}
    end
  end

  defp check_input_budget(data, path, depth, remaining, limits) do
    with :ok <- budget(:encode, path, depth, remaining, limits) do
      check_input_children(data, path, depth + 1, remaining - 1, limits)
    end
  end

  defp check_input_children(data, path, depth, remaining, limits)
       when is_map(data) and not is_struct(data) do
    Enum.reduce_while(data, {:ok, remaining}, fn {key, value}, {:ok, left} ->
      with {:ok, left} <- check_input_budget(key, path, depth, left, limits),
           {:ok, left} <- check_input_budget(value, [key | path], depth, left, limits) do
        {:cont, {:ok, left}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp check_input_children(data, path, depth, remaining, limits) when is_list(data) do
    Enum.reduce_while(data, {:ok, remaining, 0}, fn value, {:ok, left, index} ->
      case check_input_budget(value, [index | path], depth, left, limits) do
        {:ok, left} -> {:cont, {:ok, left, index + 1}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, left, _index} -> {:ok, left}
      error -> error
    end
  end

  defp check_input_children(_data, _path, _depth, remaining, _limits), do: {:ok, remaining}

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

  defp verify(yaml, data, limits) do
    case decode(yaml, Map.to_list(limits)) do
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
