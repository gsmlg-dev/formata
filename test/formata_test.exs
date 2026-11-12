defmodule FormataTest do
  use ExUnit.Case, async: true

  alias Formata.Error
  alias Formata.Schema

  doctest Formata
  doctest Formata.Codec
  doctest Formata.Schema
  doctest Formata.Transform

  @native %{
    "name" => {:required, {:string, min: 1}},
    "port" => {:required, {:integer, range: {1, 65_535}}},
    "tags" => {:list, :string},
    "db" => %{"host" => {:required, :string}, "pool" => {:integer, gt: 0}}
  }

  @json_schema %{
    "$schema" => "https://json-schema.org/draft/2020-12/schema",
    "type" => "object",
    "required" => ["name", "port"],
    "properties" => %{
      "name" => %{"type" => "string", "minLength" => 1},
      "port" => %{"type" => "integer", "minimum" => 1, "maximum" => 65_535},
      "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
      "db" => %{
        "type" => "object",
        "required" => ["host"],
        "properties" => %{"host" => %{"type" => "string"}, "pool" => %{"type" => "integer"}}
      }
    },
    "additionalProperties" => false
  }

  @documents %{
    json: ~s({"name":"api","port":8080,"tags":["a","b"],"db":{"host":"localhost","pool":5}}),
    toml: """
    name = "api"
    port = 8080
    tags = ["a", "b"]

    [db]
    host = "localhost"
    pool = 5
    """,
    yaml: """
    name: api
    port: 8080
    tags: [a, b]
    db:
      host: localhost
      pool: 5
    """
  }

  @expected %{
    "name" => "api",
    "port" => 8080,
    "tags" => ["a", "b"],
    "db" => %{"host" => "localhost", "pool" => 5}
  }

  for format <- [:json, :toml, :yaml] do
    describe "#{format} workflow" do
      test "decode -> validate (native and JSON Schema) -> encode -> decode" do
        {:ok, native} = Schema.native(@native)
        {:ok, json_schema} = Schema.json_schema(@json_schema)

        assert {:ok, data} = Formata.decode(@documents[unquote(format)], unquote(format))
        assert data == @expected
        assert :ok = Formata.validate(data, native)
        assert :ok = Formata.validate(data, json_schema)

        for target <- [:json, :toml, :yaml] do
          assert {:ok, encoded} = Formata.encode(data, target)
          assert {:ok, ^data} = Formata.decode(encoded, target)

          assert {:ok, ^encoded} =
                   Formata.convert(@documents[unquote(format)], unquote(format), target)
        end
      end

      test "invalid data is reported by both schema systems" do
        {:ok, native} = Schema.native(@native)
        {:ok, json_schema} = Schema.json_schema(@json_schema)
        {:ok, data} = Formata.decode(@documents[unquote(format)], unquote(format))
        data = %{data | "port" => 0} |> put_in(["db", "host"], 1)

        assert {:error, native_errors} = Formata.validate(data, native)
        assert {:error, json_errors} = Formata.validate(data, json_schema)

        for errors <- [native_errors, json_errors] do
          assert errors |> Enum.map(& &1.path) |> Enum.sort() == [["db", "host"], ["port"]]
          assert Enum.all?(errors, &(&1.kind == :validation))
        end
      end
    end
  end

  test "error kinds are distinguishable across the workflow" do
    {:ok, schema} = Schema.native(%{"n" => :integer})

    assert {:error, [%Error{kind: :parse}]} = Formata.decode("{", :json)
    assert {:error, [%Error{kind: :parse}]} = Formata.decode("a = ", :toml)
    assert {:error, [%Error{kind: :parse}]} = Formata.decode("a: [", :yaml)
    assert {:error, [%Error{kind: :schema}]} = Schema.native(%{"n" => :int})
    assert {:error, [%Error{kind: :schema}]} = Schema.json_schema(%{"type" => 1})
    assert {:error, [%Error{kind: :validation}]} = Formata.validate(%{"n" => "1"}, schema)
    assert {:error, [%Error{kind: :encode}]} = Formata.encode(%{"n" => nil}, :toml)

    assert {:error, [%Error{kind: :transform}]} =
             Formata.Transform.stringify_keys(%{:a => 1, "a" => 2})

    assert {:error, [%Error{kind: :unsupported}]} = Formata.decode("x", :xml)
    assert {:error, [%Error{kind: :unsupported}]} = Formata.validate(%{}, schema, unknown: :strip)

    {:ok, coercing} = Schema.native(%{"n" => {:coerce, :integer}})
    assert {:error, [%Error{kind: :transform}]} = Formata.cast(%{"n" => "x"}, coercing)
  end

  describe "convert" do
    test "rejects unrepresentable values instead of losing them" do
      assert {:error, [%Error{kind: :encode, code: :unrepresentable, path: ["a"], format: :toml}]} =
               Formata.convert(~s({"a": null, "b": 1}), :json, :toml)

      assert {:error, [%Error{kind: :encode, code: :invalid_root}]} =
               Formata.convert("[1, 2]", :json, :toml)

      assert {:error, [%Error{kind: :encode, code: :unrepresentable, path: ["at"]}]} =
               Formata.convert("at = 2024-01-01", :toml, :json)

      assert {:error, [%Error{kind: :encode, code: :unrepresentable, path: ["x"]}]} =
               Formata.convert("x = inf", :toml, :json)

      assert {:error, [%Error{kind: :encode, code: :invalid_key, path: []}]} =
               Formata.convert("1: one", :yaml, :json)
    end

    test "explicit transformations make the loss intentional" do
      assert {:ok, ~s(b = 1\n)} =
               Formata.convert(~s({"a": null, "b": 1}), :json, :toml, transforms: [:drop_nils])

      assert {:ok, ~s(a = ""\nb = 1\n)} =
               Formata.convert(~s({"a": null, "b": 1}), :json, :toml,
                 transforms: [{:replace_nils, ""}]
               )

      assert {:ok, ~s({"at":"2024-01-01"})} =
               Formata.convert("at = 2024-01-01", :toml, :json,
                 transforms: [:temporal_to_iso8601]
               )

      assert {:ok, ~s({"x":"inf"})} =
               Formata.convert("x = inf", :toml, :json, transforms: [:special_floats_to_strings])

      assert {:ok, ~s({"1":"one"})} =
               Formata.convert("1: one", :yaml, :json, transforms: [:stringify_keys])
    end

    test "custom transformation functions and their contract" do
      upcase = fn data -> {:ok, Map.new(data, fn {k, v} -> {String.upcase(k), v} end)} end
      assert {:ok, ~s({"A":1})} = Formata.convert(~s({"a":1}), :json, :json, transforms: [upcase])

      assert {:error, [%Error{kind: :transform, code: :invalid_transform_result}]} =
               Formata.convert(~s({"a":1}), :json, :json, transforms: [fn _ -> :oops end])

      assert {:error, [%Error{kind: :unsupported, code: :unknown_transform}]} =
               Formata.convert(~s({"a":1}), :json, :json, transforms: [:nope])
    end

    test "TOML date/time and special values survive TOML -> TOML but not TOML -> YAML" do
      toml = "d = 2024-01-01\nt = 10:00:00\nldt = 2024-01-01T10:00:00\nf = nan\n"
      assert {:ok, data} = Formata.decode(toml, :toml)
      assert {:ok, again} = Formata.convert(toml, :toml, :toml)
      assert {:ok, ^data} = Formata.decode(again, :toml)
      assert {:error, [%Error{code: :unrepresentable} | _]} = Formata.convert(toml, :toml, :yaml)
    end

    test "codec options are forwarded" do
      assert {:ok, "{\n  \"a\": 1\n}"} =
               Formata.convert("a = 1", :toml, :json, encode: [pretty: true])
    end
  end

  describe "semantic round trips within each documented domain" do
    test "JSON domain through every codec" do
      data = %{
        "s" => "line\n\"quoted\" \\ é",
        "i" => -42,
        "f" => 0.1,
        "b" => false,
        "l" => [1, [2, [3]], %{"x" => "y"}],
        "m" => %{"deep" => %{"er" => %{}}},
        "e" => []
      }

      for format <- [:json, :toml, :yaml] do
        assert {:ok, encoded} = Formata.encode(data, format)
        assert {:ok, ^data} = Formata.decode(encoded, format), "#{format} round trip"
      end
    end

    test "null round-trips in JSON and YAML" do
      data = %{"a" => nil, "b" => [nil]}

      for format <- [:json, :yaml] do
        assert {:ok, encoded} = Formata.encode(data, format)
        assert {:ok, ^data} = Formata.decode(encoded, format)
      end
    end

    test "special floats round-trip in TOML and YAML" do
      data = %{"p" => :infinity, "n" => :negative_infinity, "q" => :nan}

      for format <- [:toml, :yaml] do
        assert {:ok, encoded} = Formata.encode(data, format)
        assert {:ok, ^data} = Formata.decode(encoded, format)
      end
    end
  end

  describe "custom codecs" do
    defmodule Upper do
      @behaviour Formata.Codec
      def format, do: :upper
      def decode(input, _opts), do: {:ok, String.downcase(input)}
      def encode(data, _opts), do: {:ok, String.upcase(data)}
    end

    test "any module implementing the behaviour can be used as a format" do
      assert {:ok, "abc"} = Formata.decode("ABC", Upper)
      assert {:ok, "ABC"} = Formata.encode("abc", Upper)

      assert {:ok, ~s("ABC")} =
               Formata.convert("ABC", Upper, :json, transforms: [&{:ok, String.upcase(&1)}])
    end
  end
end
