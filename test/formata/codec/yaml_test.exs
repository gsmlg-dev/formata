defmodule Formata.Codec.YAMLTest do
  use ExUnit.Case, async: true

  alias Formata.Error

  describe "decode" do
    test "decodes a single document with string keys" do
      input = """
      name: app
      ports: [80, 443]
      ratio: 0.5
      enabled: true
      nothing: null
      nested:
        key: value
      """

      assert {:ok,
              %{
                "name" => "app",
                "ports" => [80, 443],
                "ratio" => 0.5,
                "enabled" => true,
                "nothing" => nil,
                "nested" => %{"key" => "value"}
              }} = Formata.decode(input, :yaml)
    end

    test "scalar and sequence roots, empty stream" do
      assert {:ok, 42} = Formata.decode("42", :yaml)
      assert {:ok, ["a", "b"]} = Formata.decode("- a\n- b\n", :yaml)
      assert {:ok, nil} = Formata.decode("", :yaml)
      assert {:ok, nil} = Formata.decode("---\n", :yaml)
      assert {:ok, nil} = Formata.decode("~", :yaml)
      assert {:ok, %{}} = Formata.decode("{}", :yaml)
    end

    test "rejects multiple documents instead of picking one" do
      assert {:error, [%Error{kind: :parse, code: :multiple_documents, details: %{count: 2}}]} =
               Formata.decode("a: 1\n---\nb: 2\n", :yaml)
    end

    test "malformed YAML reports the backend location" do
      assert {:error,
              [%Error{kind: :parse, code: :syntax, backend: Formata.YamlElixir, location: loc}]} =
               Formata.decode("a: [1, 2\n", :yaml)

      assert %{line: 1, column: _} = loc
    end

    test "rejects duplicate keys with their location" do
      assert {:error,
              [%Error{kind: :parse, code: :duplicate_key, path: [], location: %{line: 2}}]} =
               Formata.decode("a: 1\na: 2\n", :yaml)

      assert {:error, [%Error{code: :duplicate_key, path: ["outer", 1]}]} =
               Formata.decode("outer:\n  - x: 1\n  - {y: 1, y: 2}\n", :yaml)
    end

    test "merge keys are explicitly unsupported" do
      input = "base: &b {x: 1}\nderived:\n  <<: *b\n  y: 2\n"

      assert {:error, [%Error{kind: :unsupported, code: :merge_key, path: ["derived"]}]} =
               Formata.decode(input, :yaml)
    end

    test "special floats use the portable atoms; no atoms from content" do
      assert {:ok, %{"a" => :infinity, "b" => :negative_infinity, "c" => :nan}} =
               Formata.decode("a: .inf\nb: -.inf\nc: .nan\n", :yaml)

      assert {:ok, %{":key" => ":value"}} = Formata.decode(":key: :value", :yaml)
    end

    test "aliases are expanded; timestamps stay strings" do
      assert {:ok, %{"a" => 1, "b" => 1, "d" => "2001-12-14"}} =
               Formata.decode("a: &x 1\nb: *x\nd: 2001-12-14\n", :yaml)
    end
  end

  describe "encode" do
    test "round-trips the YAML domain" do
      data = %{
        "s" => "text",
        "tricky" => [
          "123",
          "true",
          "null",
          "~",
          "yes",
          "",
          " lead",
          "a: b",
          "#c",
          "- x",
          "multi\nline"
        ],
        "n" => [1, -2, 1.5, -0.0, 1.0e300],
        "special" => [:infinity, :negative_infinity, :nan],
        "b" => [true, false],
        "null" => nil,
        "empty" => %{"l" => [], "m" => %{}},
        1 => "int key",
        true => "bool key"
      }

      assert {:ok, yaml} = Formata.encode(data, :yaml)
      assert {:ok, ^data} = Formata.decode(yaml, :yaml)
    end

    test "rejects temporal values and other terms outside the domain" do
      assert {:error, [%Error{kind: :encode, code: :unrepresentable, path: ["d"]}]} =
               Formata.encode(%{"d" => ~D[2024-01-01]}, :yaml)

      assert {:error, [%Error{code: :unrepresentable}]} = Formata.encode(%{"a" => :atom}, :yaml)
      assert {:error, [%Error{code: :unrepresentable}]} = Formata.encode({1, 2}, :yaml)
      assert {:error, [%Error{code: :invalid_key}]} = Formata.encode(%{key: 1}, :yaml)
      assert {:error, [%Error{code: :invalid_key}]} = Formata.encode(%{[1] => 1}, :yaml)
    end

    test "quotes implicit numeric lookalikes without changing their string type" do
      data = %{"v" => ".5"}
      assert {:ok, yaml} = Formata.encode(data, :yaml)
      assert {:ok, ^data} = Formata.decode(yaml, :yaml)
    end
  end
end
