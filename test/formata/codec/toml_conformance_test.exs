defmodule Formata.Codec.TOMLConformanceTest do
  @moduledoc """
  Conformance of `Formata.Codec.TOML.Encoder` and the `Formata.TOML` decoder
  against the TOML 1.0.0 cases of the official toml-test suite (see
  `test/fixtures/toml-test/PROVENANCE.md`).

  Encoder: each `valid` fixture's tagged JSON is converted into the encoder's
  value domain, encoded, and then decoded again by:

    * `Formata.TOML.decode/1`, and
    * Python's `tomllib` (an independent parser), when available.

  Both decodings must be semantically equal to the fixture.

  Decoder: every `valid` `.toml` input must decode to its tagged-JSON
  expectation, and every `invalid` input must be rejected.
  """
  use ExUnit.Case, async: true

  alias Formata.Codec.TOML.Encoder

  @fixture_root Path.expand("../../fixtures/toml-test", __DIR__)
  @fixtures @fixture_root |> Path.join("valid/**/*.json") |> Path.wildcard() |> Enum.sort()

  # Fixtures that genuinely cannot be represented in the encoder's domain,
  # mapped to the reason. Keep this minimal.
  @excluded %{}

  # Fixtures exposing encoder bugs, mapped to a description. These tests stay
  # enabled and tagged `:known_failure` until the encoder is fixed.
  @known_failures %{}

  @tmp_dir Path.expand("../../../tmp/#{inspect(__MODULE__)}/tomllib", __DIR__)

  @python_script ~S"""
  import datetime, json, math, os, sys, tomllib

  def tag(v):
      if isinstance(v, bool):
          return {"type": "bool", "value": "true" if v else "false"}
      if isinstance(v, int):
          return {"type": "integer", "value": str(v)}
      if isinstance(v, float):
          if math.isnan(v):
              s = "nan"
          elif math.isinf(v):
              s = "inf" if v > 0 else "-inf"
          else:
              s = repr(v)
          return {"type": "float", "value": s}
      if isinstance(v, str):
          return {"type": "string", "value": v}
      if isinstance(v, datetime.datetime):
          t = "datetime" if v.tzinfo is not None else "datetime-local"
          return {"type": t, "value": v.isoformat()}
      if isinstance(v, datetime.date):
          return {"type": "date-local", "value": v.isoformat()}
      if isinstance(v, datetime.time):
          return {"type": "time-local", "value": v.isoformat()}
      if isinstance(v, list):
          return [tag(x) for x in v]
      if isinstance(v, dict):
          return {k: tag(x) for k, x in v.items()}
      raise TypeError(f"unexpected {type(v).__name__}")

  root = sys.argv[1]
  out = {}
  for dirpath, _, files in os.walk(root):
      for f in files:
          if not f.endswith(".toml"):
              continue
          path = os.path.join(dirpath, f)
          name = os.path.relpath(path, root)[: -len(".toml")].replace(os.sep, "/")
          try:
              with open(path, "rb") as fh:
                  out[name] = {"ok": tag(tomllib.load(fh))}
          except Exception as e:
              out[name] = {"error": f"{type(e).__name__}: {e}"}
  json.dump(out, sys.stdout)
  """

  @python_skip (case System.find_executable("python3") do
                  nil ->
                    "python3 not found on PATH"

                  python ->
                    case System.cmd(python, ["-I", "-c", "import tomllib"],
                           stderr_to_stdout: true
                         ) do
                      {_, 0} -> false
                      _ -> "python3 lacks tomllib (requires Python >= 3.11)"
                    end
                end)

  setup_all do
    if @python_skip do
      %{tomllib: %{}}
    else
      on_exit(fn -> File.rm_rf!(Path.dirname(@tmp_dir)) end)
      %{tomllib: run_tomllib()}
    end
  end

  for path <- @fixtures do
    @external_resource path
    name = path |> Path.relative_to(@fixture_root) |> Path.rootname()
    excluded = Map.get(@excluded, name)
    known_failure = Map.get(@known_failures, name)

    if excluded, do: @tag(skip: "excluded: #{excluded}")
    if known_failure, do: @tag(:known_failure)

    test "Formata.TOML.decode round-trip: #{name}" do
      expected = load_fixture(unquote(path))

      assert {:ok, toml} = Encoder.encode(expected)
      assert {:ok, decoded} = Formata.TOML.decode(toml)

      assert same?(expected, decoded), """
      Formata.TOML.decode/1 result differs from the fixture.
      encoded TOML:
      #{toml}
      expected: #{inspect(expected, limit: :infinity)}
      actual:   #{inspect(decoded, limit: :infinity)}
      """
    end

    if excluded, do: @tag(skip: "excluded: #{excluded}")
    if known_failure, do: @tag(:known_failure)
    if @python_skip, do: @tag(skip: @python_skip)

    @tag :python
    test "tomllib round-trip: #{name}", %{tomllib: results} do
      expected = load_fixture(unquote(path))
      assert {:ok, toml} = Encoder.encode(expected)

      case Map.fetch!(results, unquote(name)) do
        %{"ok" => tagged} ->
          actual = from_tagged(tagged)

          assert same?(expected, actual), """
          tomllib result differs from the fixture.
          encoded TOML:
          #{toml}
          expected: #{inspect(expected, limit: :infinity)}
          actual:   #{inspect(actual, limit: :infinity)}
          """

        %{"error" => error} ->
          flunk("tomllib rejected the encoded TOML: #{error}\nencoded TOML:\n#{toml}")
      end
    end
  end

  # -- Decoder conformance ----------------------------------------------------------

  @valid_inputs @fixture_root |> Path.join("valid/**/*.toml") |> Path.wildcard() |> Enum.sort()
  @invalid_inputs @fixture_root
                  |> Path.join("invalid/**/*.toml")
                  |> Path.wildcard()
                  |> Enum.sort()

  # Invalid documents that `Formata.TOML` currently accepts, mapped to the
  # reason. These tests assert the document is still accepted, so fixing the
  # decoder makes them fail until the entry is removed from this list.
  @invalid_known_failures %{}

  for path <- @valid_inputs do
    @external_resource path
    name = path |> Path.relative_to(@fixture_root) |> Path.rootname()
    json = Path.rootname(path) <> ".json"

    test "Formata.TOML.decode valid: #{name}" do
      expected = load_fixture(unquote(json))

      assert {:ok, decoded} = Formata.TOML.decode(File.read!(unquote(path)))

      assert same?(expected, decoded), """
      Formata.TOML.decode/1 result differs from the fixture.
      expected: #{inspect(expected, limit: :infinity)}
      actual:   #{inspect(decoded, limit: :infinity)}
      """
    end
  end

  for path <- @invalid_inputs do
    @external_resource path
    name = path |> Path.relative_to(@fixture_root) |> Path.rootname()

    case Map.fetch(@invalid_known_failures, name) do
      {:ok, reason} ->
        test "Formata.TOML.decode invalid (known failure: #{reason}): #{name}" do
          assert {:ok, _} = Formata.TOML.decode(File.read!(unquote(path))),
                 "now rejected; remove #{unquote(name)} from @invalid_known_failures"
        end

      :error ->
        test "Formata.TOML.decode invalid: #{name}" do
          assert {:error, _} = Formata.TOML.decode(File.read!(unquote(path)))
        end
    end
  end

  # -- tomllib driver -----------------------------------------------------------

  # Encodes every fixture into @tmp_dir and parses them all with one python3
  # process, returning %{name => %{"ok" => tagged} | %{"error" => message}}.
  defp run_tomllib do
    File.rm_rf!(@tmp_dir)

    for path <- @fixtures,
        {:ok, toml} <- [Encoder.encode(load_fixture(path))] do
      name = path |> Path.relative_to(@fixture_root) |> Path.rootname()
      file = Path.join(@tmp_dir, name <> ".toml")
      File.mkdir_p!(Path.dirname(file))
      File.write!(file, toml)
    end

    {out, 0} = System.cmd("python3", ["-I", "-c", @python_script, @tmp_dir])
    Formata.JSON.Backend.decode!(out)
  end

  # -- Tagged JSON -> Elixir value domain -----------------------------------------

  defp load_fixture(path),
    do: path |> File.read!() |> Formata.JSON.Backend.decode!() |> from_tagged()

  defp from_tagged(%{"type" => type, "value" => value} = map)
       when map_size(map) == 2 and is_binary(type) and is_binary(value),
       do: scalar(type, value)

  defp from_tagged(map) when is_map(map), do: Map.new(map, fn {k, v} -> {k, from_tagged(v)} end)
  defp from_tagged(list) when is_list(list), do: Enum.map(list, &from_tagged/1)

  defp scalar("string", v), do: v
  defp scalar("bool", "true"), do: true
  defp scalar("bool", "false"), do: false
  defp scalar("integer", v), do: v |> String.replace("_", "") |> parse_integer()
  defp scalar("float", v), do: v |> String.downcase() |> String.replace("_", "") |> parse_float()

  defp scalar("datetime", v) do
    {:ok, dt, _offset} = v |> normalize_datetime() |> DateTime.from_iso8601()
    DateTime.shift_zone!(dt, "Etc/UTC")
  end

  defp scalar("datetime-local", v), do: v |> normalize_datetime() |> NaiveDateTime.from_iso8601!()
  defp scalar("date-local", v), do: Date.from_iso8601!(v)
  defp scalar("time-local", v), do: Time.from_iso8601!(v)

  # toml-test allows a space (or lowercase "t") as the date/time separator and
  # a lowercase "z".
  defp normalize_datetime(v), do: v |> String.upcase() |> String.replace(" ", "T", global: false)

  defp parse_integer("+" <> v), do: parse_integer(v)
  defp parse_integer("-" <> v), do: -parse_integer(v)
  defp parse_integer("0x" <> v), do: String.to_integer(v, 16)
  defp parse_integer("0o" <> v), do: String.to_integer(v, 8)
  defp parse_integer("0b" <> v), do: String.to_integer(v, 2)
  defp parse_integer(v), do: String.to_integer(v)

  defp parse_float("+" <> v), do: parse_float(v)
  defp parse_float(v) when v in ["inf", "infinity"], do: :infinity
  defp parse_float(v) when v in ["-inf", "-infinity"], do: :negative_infinity
  defp parse_float(v) when v in ["nan", "-nan"], do: :nan

  defp parse_float(v) do
    {float, ""} = Float.parse(v)
    float
  end

  # -- Semantic equality ------------------------------------------------------------

  defp same?(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) == :eq
  defp same?(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b) == :eq
  defp same?(%Date{} = a, %Date{} = b), do: Date.compare(a, b) == :eq
  defp same?(%Time{} = a, %Time{} = b), do: Time.compare(a, b) == :eq
  defp same?(%_{}, _), do: false
  defp same?(_, %_{}), do: false

  defp same?(a, b) when is_map(a) and is_map(b) do
    map_size(a) == map_size(b) and
      Enum.all?(a, fn {k, v} -> Map.has_key?(b, k) and same?(v, Map.fetch!(b, k)) end)
  end

  defp same?(a, b) when is_list(a) and is_list(b) do
    length(a) == length(b) and a |> Enum.zip(b) |> Enum.all?(fn {x, y} -> same?(x, y) end)
  end

  # Floats compare exactly, including the sign of zero; NaN is the :nan atom.
  defp same?(a, b), do: a === b
end
