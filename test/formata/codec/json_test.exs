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
      assert {:error,
              [%Error{kind: :parse, code: :syntax, backend: Formata.JSON.Backend, location: loc}]} =
               Formata.decode("{\n  \"a\": ]\n}", :json)

      assert %{offset: 9, line: 2, column: 8} = loc
    end

    test "big integers stay exact" do
      assert {:ok, 123_456_789_012_345_678_901_234_567_890} =
               Formata.decode("123456789012345678901234567890", :json)
    end
  end

  describe "decode options: comments and trailing_commas" do
    @combos [
      [],
      [comments: true],
      [trailing_commas: true],
      [comments: true, trailing_commas: true]
    ]

    @strict_docs [
      ~s({"a":[1,2.5,null,true],"b":{"c":"x"}}),
      ~s( [ 1 , "two" , { } , [ ] ] ),
      ~s("s"),
      "-0.12e+34",
      "null",
      ~s({"url":"https://example.com/a//b","re":"/not-comment/","q":"\\"//\\""})
    ]

    test "strict JSON decodes identically under every option combination" do
      for doc <- @strict_docs, opts <- @combos do
        assert Formata.decode(doc, :json, opts) == Formata.decode(doc, :json),
               "#{inspect(doc)} with #{inspect(opts)}"
      end
    end

    test "each extension is accepted only when its own option is set" do
      comment_doc = "// head\n{\"a\": /* inline */ 1} /* tail */"
      comma_doc = ~s({"a": [1, 2,], "b": {"c": 3,},})

      for opts <- @combos do
        comments? = Keyword.get(opts, :comments, false)
        commas? = Keyword.get(opts, :trailing_commas, false)

        assert match?({:ok, %{"a" => 1}}, Formata.decode(comment_doc, :json, opts)) == comments?
        assert match?({:ok, %{"a" => [1, 2]}}, Formata.decode(comma_doc, :json, opts)) == commas?
      end
    end

    test "comment syntax" do
      opts = [comments: true]

      assert {:ok, [1, 2]} = Formata.decode("[1, // one\n 2 // two\n]", :json, opts)
      assert {:ok, [1, 2]} = Formata.decode("[1, // one\r\n 2]\r\n", :json, opts)
      assert {:ok, 1} = Formata.decode("1 // to EOF", :json, opts)
      assert {:ok, 1} = Formata.decode("/* a\n multi-line\n block */ 1", :json, opts)
      assert {:ok, 1} = Formata.decode("1/**/", :json, opts)
      assert {:ok, 1} = Formata.decode("1 /* ** / */", :json, opts)
      assert {:ok, %{"k" => "v"}} = Formata.decode(~s({/*a*/"k"/*b*/:/*c*/"v"/*d*/}), :json, opts)
      assert {:ok, "é"} = Formata.decode(~s(/* é 😀 */ "é" // ü), :json, opts)

      # Comment-like string content stays string content.
      assert {:ok, %{"u" => "https://example.com/a//b", "b" => "/* x */"}} =
               Formata.decode(~s({"u": "https://example.com/a//b", "b": "/* x */"}), :json, opts)

      assert {:ok, ~s(a\\"//b)} = Formata.decode(~s("a\\\\\\"//b" // c), :json, opts)
    end

    test "invalid comments are rejected" do
      opts = [comments: true]

      for doc <- [
            "/* unterminated",
            "1 /* unterminated *",
            "/* a /* nested */ */ 1",
            "/ 1",
            "1 /",
            "# hash 1",
            "[1/**/2]",
            "tr/**/ue",
            "-/**/1",
            "1./**/5",
            "\"a\" /* \xFF */"
          ] do
        assert {:error, [%Error{kind: :parse, code: :syntax}]} = Formata.decode(doc, :json, opts),
               "expected #{inspect(doc)} to be rejected"
      end
    end

    test "trailing comma syntax" do
      opts = [trailing_commas: true]

      assert {:ok, [1, 2]} = Formata.decode("[1, 2, ]", :json, opts)
      assert {:ok, %{"x" => 1}} = Formata.decode(~s({ "x": 1, }), :json, opts)
      assert {:ok, [[1], %{"a" => [2]}]} = Formata.decode(~s([[1,],{"a":[2,],},]), :json, opts)
      assert {:ok, []} = Formata.decode("[]", :json, opts)
      assert {:ok, %{}} = Formata.decode("{}", :json, opts)

      for doc <- [
            "[1,,2]",
            "[,]",
            "[,1]",
            "{,}",
            ~s({"x":1,,}),
            "[1,,]",
            ~s({"x":}),
            ~s({"x",}),
            "1,"
          ] do
        for opts <- @combos do
          assert {:error, [%Error{code: :syntax}]} = Formata.decode(doc, :json, opts),
                 "expected #{inspect(doc)} to be rejected with #{inspect(opts)}"
        end
      end
    end

    test "duplicate keys are still rejected, including escaped equivalents" do
      opts = [comments: true, trailing_commas: true]

      assert {:error, [%Error{code: :duplicate_key, path: ["o"], details: %{key: "a"}}]} =
               Formata.decode(~s({"o": {"a": 1, /* c */ "\\u0061": 2,},}), :json, opts)
    end

    test "error locations refer to the original input" do
      opts = [comments: true]
      doc = "/* one\n two */ {\n  \"a\": // c\n  ]\n}"

      assert {:error, [%Error{location: %{offset: 31, line: 4, column: 3}}]} =
               Formata.decode(doc, :json, opts)

      assert {:error, [%Error{location: %{offset: 13, line: 2, column: 9}}]} =
               Formata.decode("[1]\r\n/* open\r", :json, opts)
    end

    test "invalid options fail predictably" do
      assert {:error,
              [%Error{kind: :unsupported, code: :invalid_option, details: %{option: :comments}}]} =
               Formata.decode("1", :json, comments: :yes)

      assert {:error,
              [%Error{kind: :unsupported, code: :invalid_option, details: %{option: :json5}}]} =
               Formata.decode("1", :json, json5: true)

      assert {:error, [%Error{code: :invalid_option}]} =
               Formata.convert("1", :json, :json, decode: [trailing_commas: "yes"])
    end

    test "encoding stays strict JSON" do
      {:ok, data} =
        Formata.decode(~s({"a": [1,], /* c */ "b": "//"}), :json,
          comments: true,
          trailing_commas: true
        )

      assert {:ok, json} = Formata.encode(data, :json)
      assert {:ok, ^data} = Formata.decode(json, :json)
      refute json =~ ",]"
      refute json =~ "/*"
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
