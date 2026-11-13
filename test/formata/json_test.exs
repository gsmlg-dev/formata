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
