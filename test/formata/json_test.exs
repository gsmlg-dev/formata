defmodule Formata.JSONTest do
  use ExUnit.Case, async: true

  alias Formata.Error

  doctest Formata.JSON

  defmodule NotEncodable do
    defstruct [:id]
  end

  test "provides the functions Phoenix requires of a :json_library" do
    # Phoenix.json_library/0 docs: decode!/1, encode!/1, encode_to_iodata!/1.
    # Plug.Parsers.JSON calls decode!/1, or decode!/2 through an MFA tuple.
    assert Code.ensure_loaded?(Formata.JSON)

    for {fun, arity} <- [decode!: 1, decode!: 2, encode!: 1, encode_to_iodata!: 1] do
      assert function_exported?(Formata.JSON, fun, arity), "#{fun}/#{arity}"
    end
  end

  describe "decode!" do
    test "passes exact fractional and exponent tokens to a caller-supplied decoder" do
      input = ~s({"amount":0.1234567890123456789,"values":[1E+400,-0e-999,1.2300,2]})

      assert {:ok,
              %{
                "amount" => {:exact, "0.1234567890123456789"},
                "values" => [{:exact, "1E+400"}, {:exact, "-0e-999"}, {:exact, "1.2300"}, 2]
              }} = Formata.JSON.decode(input, floats: &{:exact, &1})

      assert 1.25 == Formata.JSON.decode!("1.25", floats: :native)
      assert {:error, [%Error{code: :syntax}]} = Formata.JSON.decode("1E+400")
      assert {:error, [%Error{code: :syntax}]} = Formata.JSON.decode("1e+", floats: &{:exact, &1})
    end

    test "preserves nested object order through edits and encoding" do
      input = ~s({"z":1,"settings":{"b":true,"a":2},"items":[{"y":3,"x":4}]})
      assert {:ok, object} = Formata.JSON.decode(input, objects: :ordered_objects)
      assert %Formata.JSON.OrderedObject{} = object
      assert Formata.JSON.encode!(object) == input
      assert Enum.map(object, &elem(&1, 0)) == ["z", "settings", "items"]

      edited = put_in(object["settings"]["a"], 5)

      assert Formata.JSON.encode!(edited) ==
               ~s({"z":1,"settings":{"b":true,"a":5},"items":[{"y":3,"x":4}]})

      assert {5, restored} = pop_in(edited["settings"]["a"])
      assert Enum.to_list(restored["settings"]) == [{"b", true}]

      assert Formata.JSON.decode!("{}", objects: :ordered_objects) ==
               Formata.JSON.OrderedObject.new([])
    end

    test "rejects duplicate and escaped keys in ordered mode with their path" do
      for opts <- [
            [objects: :ordered_objects],
            [objects: :ordered_objects, floats: &{:exact, &1}]
          ] do
        assert {:error, [%Error{code: :duplicate_key, path: ["a", 0], details: %{key: "b"}}]} =
                 Formata.JSON.decode(~s({"a":[{"b":1,"\\u0062":2}]}), opts)
      end
    end

    test "validates application decode options and preserves callback exceptions" do
      for opts <- [[floats: :decimals], [floats: fn _, _ -> 1 end], [objects: :pairs], [:bad]] do
        assert {:error, [%Error{kind: :unsupported, code: :invalid_option}]} =
                 Formata.JSON.decode("{}", opts)

        assert_raise Error, fn -> Formata.JSON.decode!("{}", opts) end
      end

      assert_raise ArgumentError, "callback failure", fn ->
        Formata.JSON.decode("1.5", floats: fn _ -> raise ArgumentError, "callback failure" end)
      end
    end

    test "returns string-keyed data and creates no atoms" do
      key = "formata_json_never_an_atom_#{System.unique_integer([:positive])}"

      assert %{^key => [1, 2.5, nil, true, "é"]} =
               Formata.JSON.decode!(~s({"#{key}": [1, 2.5, null, true, "é"]}))

      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
    end

    test "raises Formata.Error with a location on invalid input" do
      error = assert_raise Error, fn -> Formata.JSON.decode!("{\n  \"a\": ]\n}") end

      assert %Error{kind: :parse, code: :syntax, location: %{offset: 9, line: 2, column: 8}} =
               error
    end

    test "rejects duplicate keys, including escaped equivalents" do
      error =
        assert_raise Error, fn -> Formata.JSON.decode!(~s({"a": {"b": 1, "\\u0062": 2}})) end

      assert %Error{code: :duplicate_key, path: ["a"], details: %{key: "b"}} = error
    end

    test "is strict by default and accepts :json decode options" do
      assert_raise Error, fn -> Formata.JSON.decode!("[1,] // c") end
      assert [1] = Formata.JSON.decode!("[1,] // c", comments: true, trailing_commas: true)

      error = assert_raise Error, fn -> Formata.JSON.decode!("1", keys: :atoms) end
      assert %Error{kind: :unsupported, code: :invalid_option} = error
    end
  end

  describe "encode! and encode_to_iodata!" do
    test "pretty output supports the JSON.Encoder value domain" do
      data = %{
        status: :ok,
        object: %Formata.Test.JSONDerived{id: 1, name: "Ada"},
        date: ~D[2024-01-02],
        text: "a\\\"b\\nc",
        empty: %{}
      }

      pretty = Formata.JSON.encode!(data, pretty: true)
      assert String.contains?(pretty, "\n  \"status\": \"ok\"")
      assert Formata.JSON.decode!(pretty) == Formata.JSON.decode!(JSON.encode!(data))
      assert IO.iodata_to_binary(Formata.JSON.encode_to_iodata!(data, pretty: true)) == pretty
      assert Formata.JSON.encode!(data, pretty: false) == JSON.encode!(data)
      assert Formata.JSON.encode!(1, pretty: true) == "1"
      assert Formata.JSON.encode!([], pretty: true) == "[]"
    end

    test "pretty output retains ordered objects, including inside derived structs" do
      ordered = Formata.JSON.decode!(~s({"z":1,"a":2}), objects: :ordered_objects)
      assert Formata.JSON.encode!(ordered, pretty: true) == "{\n  \"z\": 1,\n  \"a\": 2\n}"

      assert Formata.JSON.decode!(
               Formata.JSON.encode!(%Formata.Test.JSONDerived{id: 1, name: ordered}, pretty: true)
             ) == %{"id" => 1, "name" => %{"z" => 1, "a" => 2}}
    end

    test "rejects invalid encoding options" do
      for opts <- [[pretty: :yes], [escape: :html_safe], [:bad]] do
        error = assert_raise Error, fn -> Formata.JSON.encode!(%{}, opts) end
        assert %Error{kind: :unsupported, code: :invalid_option} = error
        assert_raise Error, fn -> Formata.JSON.encode_to_iodata!(%{}, opts) end
      end
    end

    test "accept what Phoenix and LiveView send" do
      data = %{
        0 => "integer key",
        status: :ok,
        data: [%{id: 1, at: ~U[2024-01-02 03:04:05Z], day: ~D[2024-01-02]}, nil, true]
      }

      json = Formata.JSON.encode!(data)
      assert is_binary(json)
      assert IO.iodata_to_binary(Formata.JSON.encode_to_iodata!(data)) == json

      assert %{
               "status" => "ok",
               "data" => [
                 %{"id" => 1, "at" => "2024-01-02T03:04:05Z", "day" => "2024-01-02"},
                 nil,
                 true
               ],
               "0" => "integer key"
             } = Formata.JSON.decode!(json)
    end

    test "encode structs that derive JSON.Encoder" do
      assert ~s({"id":1,"name":"Ada"}) =
               Formata.JSON.encode!(%Formata.Test.JSONDerived{id: 1, name: "Ada"})
    end

    test "raise for terms JSON cannot represent" do
      assert_raise Protocol.UndefinedError, fn -> Formata.JSON.encode!(%NotEncodable{id: 1}) end
      assert_raise Protocol.UndefinedError, fn -> Formata.JSON.encode_to_iodata!({1, 2}) end
    end

    test "match Elixir's JSON" do
      data = %{"a" => [1, 1.5, "x\u2028y", "</script>"], b: %{c: false}}
      assert Formata.JSON.encode!(data) == JSON.encode!(data)
    end
  end
end
