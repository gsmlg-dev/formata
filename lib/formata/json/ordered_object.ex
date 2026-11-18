defmodule Formata.JSON.OrderedObject do
  @moduledoc """
  A JSON object retaining property order through decoding, edits, and encoding.

  A wrapper around a keyword (that supports non-atom keys) allowing for
  proper protocol implementations.

  Implements the `Access` behaviour and `Enumerable` protocol with
  complexity similar to keywords/lists.

  Decode with `Formata.JSON.decode/2` using `objects: :ordered_objects`,
  or construct with `new/1`. Keys decoded from JSON are always strings.
  Updating an existing key keeps its position; adding a key through `Access`
  prepends it. `pop_in/1` removes a key without reordering the others.

  Implements Elixir's `JSON.Encoder`, so ordered objects may also appear
  inside maps, lists, and structs that derive that protocol. Encoding rejects
  duplicate keys, including keys that become equal when encoded (such as
  `:name` and `"name"`), with an `ErlangError` containing `{:duplicate_key, key}`.
  Like Elixir's JSON maps, encoding supports string, atom, and numeric keys.
  """

  @behaviour Access

  @type key :: String.t() | atom | number
  @type t :: %__MODULE__{values: [{key, term()}]}

  defstruct values: []

  @doc ~S"""
  Creates a new ordered object from a list of key-value pairs.

  ## Example

      iex> %{a: 1, c: 3, b: 2}
      ...> |> Enum.sort()
      ...> |> Formata.JSON.OrderedObject.new()
      ...> |> Formata.JSON.encode!()
      "{\"a\":1,\"b\":2,\"c\":3}"

  """
  def new(values) when is_list(values) do
    %__MODULE__{values: values}
  end

  @impl Access
  def fetch(%__MODULE__{values: values}, key) do
    case :lists.keyfind(key, 1, values) do
      {_, value} -> {:ok, value}
      false -> :error
    end
  end

  @impl Access
  def get_and_update(%__MODULE__{values: values} = obj, key, function) do
    {result, new_values} = get_and_update(values, [], key, function)
    {result, %{obj | values: new_values}}
  end

  @impl Access
  def pop(%__MODULE__{values: values} = obj, key, default \\ nil) do
    case :lists.keyfind(key, 1, values) do
      {_, value} -> {value, %{obj | values: delete_key(values, key)}}
      false -> {default, obj}
    end
  end

  defp get_and_update([{key, current} | t], acc, key, fun) do
    case fun.(current) do
      {get, value} ->
        {get, :lists.reverse(acc, [{key, value} | t])}

      :pop ->
        {current, :lists.reverse(acc, t)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  defp get_and_update([{_, _} = h | t], acc, key, fun), do: get_and_update(t, [h | acc], key, fun)

  defp get_and_update([], acc, key, fun) do
    case fun.(nil) do
      {get, update} ->
        {get, [{key, update} | :lists.reverse(acc)]}

      :pop ->
        {nil, :lists.reverse(acc)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  defp delete_key([{key, _} | tail], key), do: delete_key(tail, key)
  defp delete_key([{_, _} = pair | tail], key), do: [pair | delete_key(tail, key)]
  defp delete_key([], _key), do: []
end

defimpl JSON.Encoder, for: Formata.JSON.OrderedObject do
  def encode(%{values: values}, encoder) do
    :json.encode_key_value_list_checked(values, encoder)
  end
end

defimpl Enumerable, for: Formata.JSON.OrderedObject do
  def count(%{values: []}), do: {:ok, 0}
  def count(_obj), do: {:error, __MODULE__}

  def member?(%{values: []}, _value), do: {:ok, false}
  def member?(_obj, _value), do: {:error, __MODULE__}

  def slice(%{values: []}), do: {:ok, 0, fn _, _ -> [] end}
  def slice(_obj), do: {:error, __MODULE__}

  def reduce(%{values: values}, acc, fun), do: Enumerable.List.reduce(values, acc, fun)
end

defimpl Formata.JSON.Backend.Encoder, for: Formata.JSON.OrderedObject do
  def encode(%{values: values}, opts) do
    Formata.JSON.Backend.Encode.keyword(values, opts)
  end
end
