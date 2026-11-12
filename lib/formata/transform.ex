defmodule Formata.Transform do
  @moduledoc """
  Explicit, opt-in data transformations.

  Encoders never drop, stringify, or replace values on their own. When a value
  cannot be represented in a target format, call one of these functions (or pass
  them to `Formata.convert/4` with `:transforms`) to make the loss explicit.

  Every transformation returns `{:ok, data}` or `{:error, [%Formata.Error{kind: :transform}]}`.

      iex> Formata.Transform.drop_nils(%{"a" => 1, "b" => nil})
      {:ok, %{"a" => 1}}

      iex> Formata.Transform.temporal_to_iso8601(%{"on" => ~D[2024-05-01]})
      {:ok, %{"on" => "2024-05-01"}}
  """

  alias Formata.Error

  @type transform ::
          :drop_nils
          | :temporal_to_iso8601
          | :stringify_keys
          | :special_floats_to_strings
          | {:replace_nils, term}
          | (term -> {:ok, term} | {:error, [Error.t(), ...]})

  @doc """
  Applies a list of transformations in order, stopping at the first error.

  Each element is a transformation name (`:drop_nils`, `:temporal_to_iso8601`,
  `:stringify_keys`, `:special_floats_to_strings`), `{:replace_nils, value}`,
  or a one-argument function returning `{:ok, data} | {:error, errors}`.

      iex> Formata.Transform.apply_all(%{"a" => nil, "t" => ~T[10:00:00]}, [:drop_nils, :temporal_to_iso8601])
      {:ok, %{"t" => "10:00:00"}}
  """
  @spec apply_all(term, [transform]) :: {:ok, term} | {:error, [Error.t(), ...]}
  def apply_all(data, transforms) when is_list(transforms) do
    Enum.reduce_while(transforms, {:ok, data}, fn transform, {:ok, data} ->
      case run(transform, data) do
        {:ok, data} -> {:cont, {:ok, data}}
        {:error, [_ | _]} = error -> {:halt, error}
      end
    end)
  end

  defp run(:drop_nils, data), do: drop_nils(data)
  defp run(:temporal_to_iso8601, data), do: temporal_to_iso8601(data)
  defp run(:stringify_keys, data), do: stringify_keys(data)
  defp run(:special_floats_to_strings, data), do: special_floats_to_strings(data)
  defp run({:replace_nils, value}, data), do: replace_nils(data, value)

  defp run(fun, data) when is_function(fun, 1) do
    case fun.(data) do
      {:ok, data} ->
        {:ok, data}

      {:error, [%Error{} | _]} = error ->
        error

      other ->
        Error.error(
          :transform,
          :invalid_transform_result,
          "transformation must return {:ok, data} or {:error, [%Formata.Error{}]}, got: #{inspect(other, limit: 5)}"
        )
    end
  end

  defp run(other, _data) do
    Error.error(:unsupported, :unknown_transform, "unknown transformation #{inspect(other)}",
      details: %{transform: other}
    )
  end

  @doc """
  Removes map entries whose value is `nil`, recursively. `nil` list elements
  are kept, because removing them would shift positions.

      iex> Formata.Transform.drop_nils(%{"a" => %{"b" => nil, "c" => [nil, 1]}})
      {:ok, %{"a" => %{"c" => [nil, 1]}}}
  """
  @spec drop_nils(term) :: {:ok, term}
  def drop_nils(data), do: {:ok, do_drop_nils(data)}

  defp do_drop_nils(%_{} = struct), do: struct

  defp do_drop_nils(map) when is_map(map) do
    for {k, v} <- map, v != nil, into: %{}, do: {k, do_drop_nils(v)}
  end

  defp do_drop_nils(list) when is_list(list), do: Enum.map(list, &do_drop_nils/1)
  defp do_drop_nils(value), do: value

  @doc """
  Replaces every `nil` (map values and list elements) with `value`.

      iex> Formata.Transform.replace_nils(%{"a" => nil, "b" => [nil]}, "")
      {:ok, %{"a" => "", "b" => [""]}}
  """
  @spec replace_nils(term, term) :: {:ok, term}
  def replace_nils(data, value), do: {:ok, do_replace_nils(data, value)}

  defp do_replace_nils(nil, value), do: value
  defp do_replace_nils(%_{} = struct, _value), do: struct

  defp do_replace_nils(map, value) when is_map(map),
    do: Map.new(map, fn {k, v} -> {k, do_replace_nils(v, value)} end)

  defp do_replace_nils(list, value) when is_list(list),
    do: Enum.map(list, &do_replace_nils(&1, value))

  defp do_replace_nils(other, _value), do: other

  @doc """
  Converts `Date`, `Time`, `NaiveDateTime`, and `DateTime` values to ISO 8601
  strings, recursively.

      iex> Formata.Transform.temporal_to_iso8601([~U[2024-01-02 03:04:05Z]])
      {:ok, ["2024-01-02T03:04:05Z"]}
  """
  @spec temporal_to_iso8601(term) :: {:ok, term}
  def temporal_to_iso8601(data), do: {:ok, do_temporal(data)}

  defp do_temporal(%Date{} = v), do: Date.to_iso8601(v)
  defp do_temporal(%Time{} = v), do: Time.to_iso8601(v)
  defp do_temporal(%NaiveDateTime{} = v), do: NaiveDateTime.to_iso8601(v)
  defp do_temporal(%DateTime{} = v), do: DateTime.to_iso8601(v)
  defp do_temporal(%_{} = struct), do: struct
  defp do_temporal(map) when is_map(map), do: Map.new(map, fn {k, v} -> {k, do_temporal(v)} end)
  defp do_temporal(list) when is_list(list), do: Enum.map(list, &do_temporal/1)
  defp do_temporal(other), do: other

  @doc """
  Converts `:infinity`, `:negative_infinity`, and `:nan` to the strings
  `"inf"`, `"-inf"`, and `"nan"`, recursively.

      iex> Formata.Transform.special_floats_to_strings(%{"x" => :infinity})
      {:ok, %{"x" => "inf"}}
  """
  @spec special_floats_to_strings(term) :: {:ok, term}
  def special_floats_to_strings(data), do: {:ok, do_special(data)}

  defp do_special(:infinity), do: "inf"
  defp do_special(:negative_infinity), do: "-inf"
  defp do_special(:nan), do: "nan"
  defp do_special(%_{} = struct), do: struct
  defp do_special(map) when is_map(map), do: Map.new(map, fn {k, v} -> {k, do_special(v)} end)
  defp do_special(list) when is_list(list), do: Enum.map(list, &do_special/1)
  defp do_special(other), do: other

  @doc """
  Converts atom, integer, float, and boolean map keys to strings, recursively.

  Fails with `:key_collision` if two keys of one map would become the same
  string (for example `:a` and `"a"`), and with `:invalid_key` for keys that have
  no string form (`nil`, tuples, lists, maps, ...).

      iex> Formata.Transform.stringify_keys(%{name: "Ada", tags: %{1 => true}})
      {:ok, %{"name" => "Ada", "tags" => %{"1" => true}}}

      iex> {:error, [%Formata.Error{code: :key_collision}]} =
      ...>   Formata.Transform.stringify_keys(%{:a => 1, "a" => 2})
  """
  @spec stringify_keys(term) :: {:ok, term} | {:error, [Error.t(), ...]}
  def stringify_keys(data) do
    case do_stringify(data, []) do
      {:ok, data} -> {:ok, data}
      {:error, error} -> {:error, [error]}
    end
  end

  defp do_stringify(%_{} = struct, _path), do: {:ok, struct}

  defp do_stringify(map, path) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.reduce_while({:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, key} <- string_key(k, path),
           :ok <- unique_key(acc, key, k, path),
           {:ok, value} <- do_stringify(v, [key | path]) do
        {:cont, {:ok, Map.put(acc, key, value)}}
      else
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp do_stringify(list, path) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item, i}, {:ok, acc} ->
      case do_stringify(item, [i | path]) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp do_stringify(other, _path), do: {:ok, other}

  defp string_key(k, _path) when is_binary(k), do: {:ok, k}
  defp string_key(k, _path) when is_boolean(k), do: {:ok, Atom.to_string(k)}
  defp string_key(k, _path) when is_atom(k) and not is_nil(k), do: {:ok, Atom.to_string(k)}
  defp string_key(k, _path) when is_integer(k), do: {:ok, Integer.to_string(k)}
  defp string_key(k, _path) when is_float(k), do: {:ok, Float.to_string(k)}

  defp string_key(k, path) do
    {:error,
     Error.new(:transform, :invalid_key, "key #{inspect(k)} has no string form",
       backend: __MODULE__,
       path: Enum.reverse(path),
       details: %{key: k}
     )}
  end

  defp unique_key(acc, key, original, path) do
    if Map.has_key?(acc, key) do
      {:error,
       Error.new(
         :transform,
         :key_collision,
         "key #{inspect(original)} collides with another key as #{inspect(key)}",
         backend: __MODULE__,
         path: Enum.reverse(path),
         details: %{key: original, string_key: key}
       )}
    else
      :ok
    end
  end
end
