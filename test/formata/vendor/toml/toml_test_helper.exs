# Test support ported from gsmlg_toml (apps/gsmlg_toml/test/support/assertions.ex
# and converter.ex at gsmlg-dev/gsmlg_umbrella ce418646e3cb5f463eb7f863549c6de765821607).
# Loaded with Code.require_file/2 by the tests in this directory.

defmodule Formata.Vendor.Toml.Assertions do
  @moduledoc false
  import ExUnit.Assertions

  alias Formata.Vendor.Toml.JsonConverter

  @doc """
  Given a path to a TOML file, asserts that parsing succeeds and
  conversion to it's JSON equivalent matches the expected result.

  The expected result should be contained in a .json file of the same
  name as the .toml file given, in the same directory. The result is
  compared with `assert_deep_equal/2`.
  """
  def assert_toml_valid(path) do
    json = Path.join([Path.dirname(path), Path.basename(path, ".toml") <> ".json"])

    case Formata.Toml.decode_file(path) do
      {:error, {:invalid_toml, reason}} when is_binary(reason) ->
        flunk(reason)

      {:ok, decoded} ->
        expected = JsonConverter.parse_json_file!(json)
        # typed = JsonConverter.to_typed_map(decoded)
        assert_deep_equal(expected, JsonConverter.to_json_map(decoded))
    end
  end

  @doc """
  Asserts that two items are deeply equivalent, meaning that
  all lists have the same items, all maps have the same keys, and all values
  are the same. Order of items is not considered in this equality comparison.
  """
  def assert_deep_equal(a, b) do
    if do_deep_equal(a, b) do
      assert true
    else
      assert a == b
    end
  end

  defp do_deep_equal(a, b) when is_map(a) and is_map(b) do
    asort = a |> Map.to_list() |> Enum.sort_by(&to_sort_key/1)
    bsort = b |> Map.to_list() |> Enum.sort_by(&to_sort_key/1)

    if map_size(a) == map_size(b) do
      asort
      |> Enum.zip(bsort)
      |> Enum.all?(fn {{ak, av}, {bk, bv}} ->
        if ak != bk do
          false
        else
          do_deep_equal(av, bv)
        end
      end)
    else
      false
    end
  end

  defp do_deep_equal(a, a), do: true

  defp do_deep_equal(a, b) when is_list(a) and is_list(b) do
    if length(a) == length(b) do
      asort = Enum.sort_by(a, &to_sort_key/1)
      bsort = Enum.sort_by(b, &to_sort_key/1)

      asort
      |> Enum.zip(bsort)
      |> Enum.all?(fn {ai, bi} ->
        do_deep_equal(ai, bi)
      end)
    else
      a == b
    end
  end

  defp do_deep_equal(a, b) do
    a == b
  end

  defp to_sort_key(v) when is_map(v), do: Enum.sort(Map.keys(v))
  defp to_sort_key(v) when is_list(v), do: Enum.sort_by(v, &to_sort_key/1)
  defp to_sort_key(v), do: v
end

defmodule Formata.Vendor.Toml.JsonConverter do
  @moduledoc false

  def parse_toml_file!(path) do
    case Formata.Toml.decode_file(path) do
      {:ok, map} ->
        Formata.Jason.encode!(to_typed_map(map), pretty: true)

      {:error, _} = err ->
        err
    end
  end

  def parse_json_file!(path) do
    Formata.Jason.decode!(File.read!(path))
  end

  def to_typed_map(map) when is_map(map) do
    for {k, v} <- map, v2 = to_typed_value(v), into: %{} do
      {k, v2}
    end
  end

  def to_json_map(map) when is_map(map) do
    for {k, v} <- map, into: %{} do
      {k, to_json_value(v)}
    end
  end

  defp to_typed_value(:infinity),
    do: %{"type" => "integer", "value" => "Infinity"}

  defp to_typed_value(:negative_infinity),
    do: %{"type" => "integer", "value" => "-Infinity"}

  defp to_typed_value(:nan),
    do: %{"type" => "integer", "value" => "NaN"}

  defp to_typed_value(:negative_nan),
    do: %{"type" => "integer", "value" => "-NaN"}

  defp to_typed_value(n) when is_integer(n),
    do: %{"type" => "integer", "value" => Integer.to_string(n)}

  defp to_typed_value(n) when is_float(n),
    do: %{"type" => "float", "value" => Float.to_string(n)}

  defp to_typed_value(s) when is_binary(s),
    do: %{"type" => "string", "value" => s}

  defp to_typed_value(true),
    do: %{"type" => "bool", "value" => "true"}

  defp to_typed_value(false),
    do: %{"type" => "bool", "value" => "false"}

  # Empty lists are treated plainly
  defp to_typed_value([]), do: []

  # Array of structs (values)
  defp to_typed_value([%_{} | _] = list) do
    %{"type" => "array", "value" => Enum.map(list, &to_typed_value/1)}
  end

  # Array value
  defp to_typed_value(list) when is_list(list),
    do: %{"type" => "array", "value" => Enum.map(list, &to_typed_value/1)}

  defp to_typed_value(%Date{} = d),
    do: %{"type" => "datetime", "value" => Date.to_iso8601(d)}

  defp to_typed_value(%Time{} = d),
    do: %{"type" => "datetime", "value" => Time.to_iso8601(d)}

  defp to_typed_value(%DateTime{} = d),
    do: %{"type" => "datetime", "value" => DateTime.to_iso8601(d)}

  defp to_typed_value(%NaiveDateTime{} = d),
    do: %{"type" => "datetime", "value" => NaiveDateTime.to_iso8601(d)}

  defp to_typed_value(map) when is_map(map) do
    to_typed_map(map)
  end

  defp to_json_value(:infinity),
    do: "Infinity"

  defp to_json_value(:negative_infinity),
    do: "-Infinity"

  defp to_json_value(:nan),
    do: "NaN"

  defp to_json_value(:negative_nan),
    do: "-NaN"

  defp to_json_value(n) when is_integer(n),
    do: n

  defp to_json_value(n) when is_float(n),
    do: n

  defp to_json_value(s) when is_binary(s),
    do: s

  defp to_json_value(true),
    do: true

  defp to_json_value(false),
    do: false

  # Empty lists are treated plainly
  defp to_json_value([]), do: []

  # Array value
  defp to_json_value(list) when is_list(list),
    do: Enum.map(list, &to_json_value/1)

  defp to_json_value(%Date{} = d),
    do: Date.to_iso8601(d)

  defp to_json_value(%Time{} = d),
    do: Time.to_iso8601(d)

  defp to_json_value(%DateTime{} = d),
    do: DateTime.to_iso8601(d)

  defp to_json_value(%NaiveDateTime{} = d),
    do: NaiveDateTime.to_iso8601(d)

  defp to_json_value(map) when is_map(map) do
    to_json_map(map)
  end
end
