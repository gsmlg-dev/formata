defmodule Formata.Codec.JSONTest do
  use ExUnit.Case, async: true

  alias Formata.Error

  doctest Formata.Codec.JSON

  describe "decode" do
    test "objects keep string keys, arrays and scalar roots are preserved" do
      assert {:ok, %{"a" => [1, 2.5, nil, true], "b" => %{"c" => "x"}}} =
               Formata.decode(~s({"a":[1,2.5,null,true],"b":{"c":"x"}}), :json)

      assert {:ok, [1, "two"]} = Formata.decode(~s([1,"two"]), :json)
      assert {:ok, "s"} = Formata.decode(~s("s"), :json)
      assert {:ok, nil} = Formata.decode("null", :json)
      assert {:ok, 42} = Formata.decode("42", :json)
    end

    test "explicit null is distinct from an absent key" do
      assert {:ok, %{"a" => nil}} = Formata.decode(~s({"a":null}), :json)
      assert {:ok, data} = Formata.decode(~s({}), :json)
      refute Map.has_key?(data, "a")
    end

    test "does not create atoms from keys" do
      key = "formata_never_an_atom_#{System.unique_integer([:positive])}"
      assert {:ok, %{^key => 1}} = Formata.decode(~s({"#{key}":1}), :json)
      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
    end

    test "duplicate keys are rejected with their path" do
      assert {:error,
              [%Error{kind: :parse, code: :duplicate_key, path: ["a"], details: %{key: "b"}}]} =
               Formata.decode(~s({"a":{"b":1,"b":2}}), :json)

      assert {:error, [%Error{code: :duplicate_key, path: [0]}]} =
               Formata.decode(~s([{"x":1,"x":1}]), :json)
    end

    test "syntax errors carry backend offset and derived line/column" do
      assert {:error, [%Error{kind: :parse, code: :syntax, backend: Jason, location: loc}]} =
               Formata.decode("{\n  \"a\": ]\n}", :json)

      assert %{offset: 9, line: 2, column: 8} = loc
    end

    test "big integers stay exact" do
      assert {:ok, 123_456_789_012_345_678_901_234_567_890} =
               Formata.decode("123456789012345678901234567890", :json)
    end
  end

  describe "encode" do
    test "encodes the JSON domain" do
      assert {:ok, json} = Formata.encode(%{"a" => [1, 2.5, nil, true, "é"]}, :json)
      assert {:ok, %{"a" => [1, 2.5, nil, true, "é"]}} = Formata.decode(json, :json)
    end

    test "pretty option" do
      assert {:ok, "{\n  \"a\": 1\n}"} = Formata.encode(%{"a" => 1}, :json, pretty: true)
    end

    test "rejects values outside the JSON domain without converting them" do
      for {value, code} <- [
            {%{a: 1}, :invalid_key},
            {%{1 => 1}, :invalid_key},
            {%{"d" => ~D[2024-01-01]}, :unrepresentable},
            {%{"f" => :infinity}, :unrepresentable},
            {%{"f" => :nan}, :unrepresentable},
            {%{"x" => :atom}, :unrepresentable},
            {%{"t" => {1, 2}}, :unrepresentable},
            {%{"s" => <<255>>}, :unrepresentable},
            {%{"u" => URI.parse("http://x")}, :unrepresentable}
          ] do
        assert {:error, [%Error{kind: :encode, code: ^code, format: :json} | _]} =
                 Formata.encode(value, :json),
               "expected #{inspect(value)} to be rejected with #{code}"
      end
    end

    test "reports every offending path" do
      assert {:error, errors} = Formata.encode(%{"a" => :x, "b" => [~T[10:00:00]]}, :json)
      assert Enum.map(errors, & &1.path) == [["a"], ["b", 0]]
    end
  end
end
