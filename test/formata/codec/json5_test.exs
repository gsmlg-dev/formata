defmodule Formata.Codec.JSON5Test do
  use ExUnit.Case, async: true

  alias Formata.Error

  doctest Formata.Codec.JSON5

  # Fixtures are written from the JSON5 1.0.0 specification
  # (https://spec.json5.org/, sections cited per case) and the ECMAScript 5.1
  # lexical grammar it references (IdentifierName, escapes, white space).

  describe "decode: spec examples" do
    test "the specification's summary example (§1)" do
      doc = """
      // comments
      {
        unquoted: 'and you can quote me on that',
        singleQuotes: 'I can use "double quotes" here',
        lineBreaks: "Look, Mom! \\
      No \\\\n's!",
        hexadecimal: 0xdecaf,
        leadingDecimalPoint: .8675309, andTrailing: 8675309.,
        positiveSign: +1,
        trailingComma: 'in objects', andIn: ['arrays',],
        "backwardsCompatible": "with JSON",
      }
      """

      assert {:ok,
              %{
                "unquoted" => "and you can quote me on that",
                "singleQuotes" => ~s(I can use "double quotes" here),
                "lineBreaks" => "Look, Mom! No \\n's!",
                "hexadecimal" => 0xDECAF,
                "leadingDecimalPoint" => 0.8675309,
                "andTrailing" => 8_675_309.0,
                "positiveSign" => 1,
                "trailingComma" => "in objects",
                "andIn" => ["arrays"],
                "backwardsCompatible" => "with JSON"
              }} = Formata.decode(doc, :json5)
    end

    test "objects and arrays (§3, §4)" do
      assert {:ok, %{"width" => 1920, "height" => 1080, "aspectRatio" => "16:9"}} =
               Formata.decode(
                 "{ width: 1920, height: 1080, 'aspectRatio': '16:9', }",
                 :json5
               )

      assert {:ok, [%{"name" => "Joe", "age" => 27}, %{"name" => "Jane", "age" => 32}]} =
               Formata.decode(
                 "[ { name: 'Joe', age: 27 }, { name: 'Jane', age: 32 }, ]",
                 :json5
               )

      assert {:ok, %{}} = Formata.decode("{}", :json5)
      assert {:ok, []} = Formata.decode("[ ]", :json5)
    end

    test "strings (§5)" do
      assert {:ok, ["Lorem ipsum dolor sit amet, consectetur adipiscing elit."]} =
               Formata.decode(
                 "['Lorem ipsum dolor sit amet, \\\nconsectetur adipiscing elit.']",
                 :json5
               )

      assert {:ok, "\u{1F600}"} = Formata.decode(~s("\\uD83D\\uDE00"), :json5)
      assert {:ok, "A"} = Formata.decode(~s('\\x41'), :json5)
      assert {:ok, "'\"\\\b\f\n\r\t\v\0"} = Formata.decode(~S("\'\"\\\b\f\n\r\t\v\0"), :json5)
      # Any other character escapes itself.
      assert {:ok, "aq€"} = Formata.decode(~S("a\q\€"), :json5)
      # Line continuations: LF, CR, CRLF, LS, PS.
      for sep <- ["\n", "\r", "\r\n", "\u2028", "\u2029"] do
        assert {:ok, "ab"} = Formata.decode("'a\\" <> sep <> "b'", :json5)
      end

      # LS and PS may appear unescaped; tabs and other characters as well.
      assert {:ok, "a\u2028b\u2029c\td"} = Formata.decode("'a\u2028b\u2029c\td'", :json5)
      assert {:ok, ~s(it's)} = Formata.decode(~S('it\'s'), :json5)
    end

    test "numbers (§6)" do
      for {doc, value} <- [
            {"123", 123},
            {"-123", -123},
            {"+123", 123},
            {"0", 0},
            {"-0", 0},
            {"1.5", 1.5},
            {".5", 0.5},
            {"-.5", -0.5},
            {"5.", 5.0},
            {"+5.e1", 50.0},
            {"1e3", 1000.0},
            {"1E-3", 0.001},
            {"0xdecaf", 0xDECAF},
            {"0XDECAF", 0xDECAF},
            {"-0xC0FFEE", -0xC0FFEE},
            {"+0x1", 1},
            {"Infinity", :infinity},
            {"+Infinity", :infinity},
            {"-Infinity", :negative_infinity},
            {"NaN", :nan},
            {"+NaN", :nan},
            {"-NaN", :nan},
            {"123456789012345678901234567890", 123_456_789_012_345_678_901_234_567_890}
          ] do
        assert {:ok, decoded} = Formata.decode(doc, :json5), doc
        assert decoded === value, "#{doc}: #{inspect(decoded)}"
      end

      assert {:ok, -0.0} = Formata.decode("-0.0", :json5)
      assert {:ok, underflow} = Formata.decode("1e-400", :json5)
      assert underflow === 0.0
    end

    test "comments and white space (§7, §8)" do
      assert {:ok, %{"a" => 1}} =
               Formata.decode(
                 "/* block\n comment */ { // line\n a: /* inline */ 1 } // end",
                 :json5
               )

      ws = "\t\v\f \u00A0\uFEFF\u1680\u2000\u200A\u2028\u2029\u202F\u205F\u3000\r\n"
      assert {:ok, [1]} = Formata.decode(ws <> "[" <> ws <> "1" <> ws <> "]" <> ws, :json5)
      # A line comment also ends at CR, LS, and PS.
      for sep <- ["\r", "\u2028", "\u2029"] do
        assert {:ok, 1} = Formata.decode("// c" <> sep <> "1", :json5)
      end

      assert {:ok, %{"s" => "// not /* a comment */"}} =
               Formata.decode("{s: '// not /* a comment */'}", :json5)
    end

    test "unquoted keys are ES5.1 IdentifierNames" do
      for {doc, key} <- [
            {"{a: 1}", "a"},
            {"{$: 1}", "$"},
            {"{_: 1}", "_"},
            {"{a1_$: 1}", "a1_$"},
            {"{ünïcödé: 1}", "ünïcödé"},
            {"{日本語: 1}", "日本語"},
            {"{Ⅻ: 1}", "Ⅻ"},
            # Mn combining mark and Nd digit (Devanagari) as IdentifierPart.
            {"{e\u0301: 1}", "e\u0301"},
            {"{a\u0966: 1}", "a\u0966"},
            # Pc connector punctuation, ZWNJ, ZWJ.
            {"{a\u203F: 1}", "a\u203F"},
            {"{a\u200C\u200D: 1}", "a\u200C\u200D"},
            # Escapes decode to IdentifierStart / IdentifierPart characters.
            {~S({\u0061b: 1}), "ab"},
            {~S({a\u0031: 1}), "a1"},
            {~S({\u00fc: 1}), "ü"},
            # Reserved words are valid IdentifierNames.
            {"{while: 1}", "while"},
            {"{true: 1}", "true"},
            {"{null: 1}", "null"},
            {"{Infinity: 1}", "Infinity"}
          ] do
        assert {:ok, %{^key => 1}} = Formata.decode(doc, :json5), doc
      end
    end

    test "plain JSON decodes as in :json" do
      for doc <- [
            ~s({"a":[1,2.5,null,true,false],"b":{"c":"x\\u00e9\\n"},"d":-0.12e+34}),
            ~s([{"x": 1}, [], {}, "", 0, -0, 1E5]),
            ~s("\\ud83d\\ude00"),
            "null"
          ] do
        assert Formata.decode(doc, :json5) === Formata.decode(doc, :json), doc
      end
    end
  end

  describe "decode: rejections" do
    test "invalid documents" do
      for doc <- [
            "",
            "{a: 1",
            "[1,,2]",
            "[,]",
            "{,}",
            "[1,,]",
            "{a 1}",
            "{1a: 1}",
            "{a-b: 1}",
            "{'a' 1}",
            ~S({\u0031: 1}),
            ~S({a\u002d: 1}),
            ~S({\x61: 1}),
            ~S({\ud83d: 1}),
            "01",
            "-01",
            "1.e",
            "1e",
            "1e+",
            "0x",
            "0xg",
            ".",
            "+",
            "++1",
            "Infinit",
            "inf",
            "nan",
            "1 2",
            "{} {}",
            "'abc",
            "'a\nb'",
            "\"a\rb\"",
            ~S("\1"),
            ~S("\01"),
            ~S("\x4"),
            ~S("\xZZ"),
            ~S("\u12"),
            ~S("\ud83d"),
            ~S("\ude00"),
            ~S("\ud83d\u0041"),
            "/* unterminated",
            "/ 1",
            "# 1",
            "\"\xFF\"",
            "undefined",
            "1e400",
            "-1e400",
            "0x" <> String.duplicate("f", 1025)
          ] do
        assert {:error, [%Error{kind: :parse, format: :json5, backend: Formata.Codec.JSON5}]} =
                 Formata.decode(doc, :json5),
               "expected #{inspect(doc)} to be rejected"
      end
    end

    test "duplicate keys, compared after decoding" do
      for doc <- [
            "{a: 1, a: 2}",
            "{a: 1, 'a': 2}",
            ~S({a: 1, "\u0061": 2}),
            ~S({\u0061: 1, a: 2}),
            ~S({'a': 1, "\x61": 2})
          ] do
        assert {:error, [%Error{kind: :parse, code: :duplicate_key, details: %{key: "a"}}]} =
                 Formata.decode(doc, :json5),
               doc
      end

      assert {:error, [%Error{code: :duplicate_key, path: ["x", 1]}]} =
               Formata.decode("{x: [{}, {k: 1, k: 2}]}", :json5)
    end

    test "errors carry locations" do
      assert {:error, [%Error{code: :syntax, location: %{offset: 12, line: 3, column: 3}}]} =
               Formata.decode("{\n  a: 1,\n  ]", :json5)

      assert {:error, [%Error{location: %{offset: 9, line: 2, column: 3}}]} =
               Formata.decode("{a: 1,\n  -}", :json5)

      assert {:error, [%Error{message: "number is outside the finite float range"}]} =
               Formata.decode("1e400", :json5)
    end

    test "options are rejected" do
      for opts <- [[comments: true], [trailing_commas: true], [json5: true]] do
        assert {:error, [%Error{kind: :unsupported, code: :invalid_option}]} =
                 Formata.decode("1", :json5, opts)
      end

      assert {:error, [%Error{code: :invalid_option}]} = Formata.encode(1, :json5, pretty: :yes)
    end

    test "does not create atoms from keys" do
      key = "formata_json5_never_an_atom_#{System.unique_integer([:positive])}"
      assert {:ok, %{^key => 1}} = Formata.decode("{#{key}: 1}", :json5)
      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
    end
  end

  describe "encode" do
    test "deterministic JSON-subset output with special numbers" do
      data = %{
        "b" => [1, 2.5, nil, true, "é\n"],
        "a" => %{"x" => :infinity},
        "n" => [:nan, :negative_infinity]
      }

      assert {:ok, ~s({"a":{"x":Infinity},"b":[1,2.5,null,true,"é\\n"],"n":[NaN,-Infinity]})} =
               Formata.encode(data, :json5)

      assert {:ok, "{\n  \"a\": [\n    1,\n    NaN\n  ],\n  \"b\": {},\n  \"c\": []\n}"} =
               Formata.encode(%{"a" => [1, :nan], "b" => %{}, "c" => []}, :json5, pretty: true)
    end

    test "pretty output for plain data matches :json" do
      data = %{"a" => [1, %{"b" => [true, nil]}], "c" => "x"}

      assert Formata.encode(data, :json5, pretty: true) ==
               Formata.encode(data, :json, pretty: true)

      assert Formata.encode(data, :json5) == Formata.encode(data, :json)
    end

    test "round trips representable data" do
      for data <- [
            %{"a" => [1, -0.0, 1.0e300, 5.0e-324, :infinity, :negative_infinity, :nan]},
            [[], %{}, [[%{"é" => "\u2028 \u0000 😀"}]]],
            "s",
            nil,
            -123_456_789_012_345_678_901_234_567_890,
            %{"nested" => %{"deep" => [%{"x" => [1, [2, [3]]]}]}}
          ],
          pretty <- [false, true] do
        assert {:ok, text} = Formata.encode(data, :json5, pretty: pretty)
        assert {:ok, decoded} = Formata.decode(text, :json5)
        assert decoded === data, text
      end
    end

    test "rejects values outside the JSON5 domain" do
      for {value, code} <- [
            {%{a: 1}, :invalid_key},
            {%{"d" => ~D[2024-01-01]}, :unrepresentable},
            {%{"x" => :atom}, :unrepresentable},
            {%{"s" => <<255>>}, :unrepresentable},
            {{1, 2}, :unrepresentable}
          ] do
        assert {:error, [%Error{kind: :encode, code: ^code, format: :json5} | _]} =
                 Formata.encode(value, :json5)
      end
    end
  end

  describe "conversion and schemas" do
    test "JSON5 to JSON for data in the JSON domain" do
      assert {:ok, ~s({"a":[1,2],"b":"x"})} =
               Formata.convert("{a: [1, 2,], b: 'x'}", :json5, :json)

      assert {:ok, ~s({"a":1})} = Formata.convert(~s({"a": 1}), :json, :json5)
    end

    test "non-finite numbers are rejected by JSON with their path unless transformed" do
      assert {:error,
              [%Error{kind: :encode, code: :unrepresentable, format: :json, path: ["x", 1]}]} =
               Formata.convert("{x: [1, NaN]}", :json5, :json)

      assert {:ok, ~s({"x":[1,"nan"]})} =
               Formata.convert("{x: [1, NaN]}", :json5, :json,
                 transforms: [:special_floats_to_strings]
               )

      assert {:ok, "x = [1, nan]\n"} = Formata.convert("{x: [1, NaN]}", :json5, :toml)
    end

    test "JSON Schema does not accept non-finite numbers" do
      {:ok, schema} = Formata.Schema.json_schema(%{"type" => "object"})
      {:ok, data} = Formata.decode("{x: Infinity}", :json5)

      assert {:error, [%Error{kind: :unsupported, code: :non_json_value, path: ["x"]}]} =
               Formata.validate(data, schema)

      {:ok, data} = Formata.decode("{x: 1}", :json5)
      assert :ok = Formata.validate(data, schema)
    end

    test "is registered as a built-in format" do
      assert {:ok, Formata.Codec.JSON5} = Formata.Codec.fetch(:json5)
      assert :json5 in Formata.Codec.formats()
    end
  end
end
