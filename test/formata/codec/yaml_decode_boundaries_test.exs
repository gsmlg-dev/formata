defmodule Formata.Codec.YAMLDecodeBoundariesTest do
  use ExUnit.Case, async: true

  alias Formata.Error

  @ladder "a: &a [x, x]\nb: &b [*a, *a]\nc: &c [*b, *b]\nd: [*c, *c]"

  test "YAML 1.2 core requires complete decimal or unsigned base-prefixed integers" do
    strings = [
      "+",
      "-",
      "0x",
      "0o",
      "+0x",
      "-0x",
      "+0o",
      "-0o",
      "+0x1",
      "-0x1",
      "+0o7",
      "-0o7",
      "0b1",
      "0x_",
      "0o_",
      "1_0"
    ]

    for scalar <- strings do
      assert {:ok, %{"v" => ^scalar}} = Formata.decode("v: " <> scalar, :yaml), scalar
      assert {:ok, %{"v" => ^scalar}} = Formata.YamlElixir.read_from_string("v: " <> scalar)
      assert :error = :formata_yamerl_node_int.string_to_integer(String.to_charlist(scalar))
    end

    for {scalar, expected} <- [
          {"0", 0},
          {"+0", 0},
          {"-0", 0},
          {"+12", 12},
          {"-12", -12},
          {"012", 12},
          {"0o12", 10},
          {"0x1aB", 427}
        ] do
      assert {:ok, %{"v" => ^expected}} = Formata.decode("v: " <> scalar, :yaml)
      assert expected == :formata_yamerl_node_int.string_to_integer(String.to_charlist(scalar))
      assert {:ok, %{"v" => ^scalar}} = Formata.decode("v: '" <> scalar <> "'", :yaml)
    end

    for {scalar, expected} <- [{"+1.5", 1.5}, {"-1.5", -1.5}, {"1e2", 100.0}, {".5", 0.5}] do
      assert {:ok, %{"v" => ^expected}} = Formata.decode("v: " <> scalar, :yaml)
    end
  end

  test "invalid explicitly tagged integers are structured syntax errors" do
    for scalar <- ["+", "-", "0x", "0o", "+0x1", "-0o1", "0x_"] do
      input = "v: !!int '" <> scalar <> "'"

      assert {:error,
              [
                %Error{
                  kind: :parse,
                  code: :syntax,
                  location: %{line: 1},
                  details: %{type: :not_an_integer}
                }
              ]} = Formata.decode(input, :yaml)

      assert {:error, %Formata.YamlElixir.ParsingError{type: :not_an_integer, line: 1}} =
               Formata.YamlElixir.read_nodes_from_string(input)
    end
  end

  test "explicit YAML 1.1 keeps its own integer schema without accepting empty productions" do
    for {scalar, expected} <- [
          {"+0x1", 1},
          {"-0x1", -1},
          {"+012", 10},
          {"-012", -10},
          {"0b101", 5},
          {"1_000", 1000},
          {"1:20", 80}
        ] do
      assert {:ok, %{"v" => ^expected}} = Formata.decode("%YAML 1.1\n---\nv: " <> scalar, :yaml)
    end

    for scalar <- ["+", "-", "0x", "0b", "0x_", "0b_"] do
      assert {:ok, %{"v" => ^scalar}} = Formata.decode("%YAML 1.1\n---\nv: " <> scalar, :yaml)

      assert {:error, [%Error{kind: :parse, code: :syntax}]} =
               Formata.decode("%YAML 1.1\n---\nv: !!int '" <> scalar <> "'", :yaml)
    end
  end

  test "scalar keys preserve null, tag identity and normalized special floats" do
    input =
      "null: nil-key\n'null': string\n1: integer\n'1': string-int\n1.0: float\ntrue: bool\n\"true\": string-bool\n.inf: positive\n-.inf: negative\n.nan: nan"

    expected = %{
      nil => "nil-key",
      "null" => "string",
      1 => "integer",
      "1" => "string-int",
      1.0 => "float",
      true => "bool",
      "true" => "string-bool",
      :infinity => "positive",
      :negative_infinity => "negative",
      :nan => "nan"
    }

    assert {:ok, ^expected} = Formata.decode(input, :yaml)
    assert {:ok, %{nil => 1}} = Formata.YamlElixir.read_from_string("null: 1")

    assert {:error, [%Error{kind: :encode, code: :invalid_key}]} =
             Formata.encode(%{nil => 1}, :yaml)
  end

  test "duplicate scalar keys are rejected after resolution and normalization" do
    for keys <- [
          ["null", "~"],
          ["1", "01"],
          ["true", "True"],
          [".inf", "+.inf"],
          [".nan", ".NaN"],
          ["'a'", "!!str a"]
        ] do
      [first, second] = keys
      column = if second == "!!str a", do: 9, else: 3
      input = "outer:\n  " <> first <> ": 1\n  " <> second <> ": 2"

      assert {:error,
              [
                %Error{
                  kind: :parse,
                  code: :duplicate_key,
                  path: ["outer"],
                  location: %{line: 3, column: ^column}
                }
              ]} = Formata.decode(input, :yaml)
    end
  end

  test "sequence and mapping keys are explicitly unsupported before lossy conversion" do
    for {input, type} <- [
          {"? [{a: 1, a: 2}]\n: value", :sequence},
          {"? {a: 1}\n: value", :mapping},
          {"? [x]\n: value", :sequence}
        ] do
      assert {:error,
              [
                %Error{
                  kind: :unsupported,
                  code: :unsupported_key,
                  path: [],
                  location: %{line: 1, column: 3},
                  details: %{type: ^type}
                }
              ]} = Formata.decode(input, :yaml)

      assert {:error, [%Error{code: :unsupported_key, path: ["outer"]}]} =
               Formata.decode("outer:\n" <> indent(input), :yaml)
    end
  end

  test "quoted and explicitly string-tagged merge spellings stay literal" do
    for key <- ["'<<'", "\"<<\"", "!!str <<", "!!str '<<'"] do
      input = key <> ": 1"
      assert {:ok, %{"<<" => 1}} = Formata.decode(input, :yaml)
      assert {:ok, %{"<<" => 1}} = Formata.YamlElixir.read_from_string(input)
      assert {:ok, %{"<<" => 1}} = Formata.YamlElixir.read_from_string(input, merge_anchors: true)
    end

    for key <- ["'<<'", "!!str <<"] do
      assert {:ok, %{"anchor" => "<<", "<<" => 1}} =
               Formata.decode("anchor: &key " <> key <> "\n*key : 1", :yaml)
    end

    assert {:error,
            [
              %Error{
                kind: :unsupported,
                code: :merge_key,
                path: ["derived"],
                location: %{line: 3, column: 3}
              }
            ]} = Formata.decode("base: &b {x: 1}\nderived:\n  <<: *b", :yaml)

    assert {:error, [%Error{code: :merge_key}]} =
             Formata.decode("anchor: &key <<\n*key : 1", :yaml)
  end

  test "flow collection anchors attach to the collection rather than its first child" do
    a = ["x", "x"]
    b = [a, a]
    c = [b, b]
    expected = %{"a" => a, "b" => b, "c" => c, "d" => [c, c]}
    assert {:ok, ^expected} = Formata.decode(@ladder, :yaml)
    assert {:ok, ^expected} = Formata.YamlElixir.read_from_string(@ladder)

    assert {:ok, %{"a" => %{"x" => 1}, "b" => %{"x" => 1}}} =
             Formata.decode("a: &a {x: 1}\nb: *a", :yaml)
  end

  test "expanded alias nodes have exact cumulative limits before conversion" do
    assert {:ok, data} = Formata.decode(@ladder, :yaml, max_nodes: 61, max_depth: 5)

    assert {:error,
            [
              %Error{
                kind: :parse,
                code: :limit_exceeded,
                path: ["d", 1],
                location: %{line: 4, column: 9},
                details: %{limit: :max_nodes, max: 60, actual: 61}
              }
            ]} = Formata.decode(@ladder, :yaml, max_nodes: 60)

    assert {:error,
            [%Error{code: :limit_exceeded, details: %{limit: :max_depth, max: 4, actual: 5}}]} =
             Formata.decode(@ladder, :yaml, max_depth: 4)

    assert {:ok, yaml} = Formata.encode(data, :yaml, max_nodes: 61, max_depth: 5)
    assert {:ok, ^data} = Formata.decode(yaml, :yaml, max_nodes: 61, max_depth: 5)

    assert {:error,
            [%Error{kind: :encode, code: :limit_exceeded, details: %{limit: :max_nodes, max: 60}}]} =
             Formata.encode(data, :yaml, max_nodes: 60)

    assert {:error,
            [%Error{kind: :encode, code: :limit_exceeded, details: %{limit: :max_depth, max: 4}}]} =
             Formata.encode(data, :yaml, max_depth: 4)
  end

  test "root depth zero and key nodes use the same encode and decode contract" do
    for {input, data} <- [{"null", nil}, {"{}", %{}}, {"[]", []}, {"42", 42}] do
      assert {:ok, ^data} = Formata.decode(input, :yaml, max_depth: 0, max_nodes: 1)
      assert {:ok, _yaml} = Formata.encode(data, :yaml, max_depth: 0, max_nodes: 1)
    end

    for {input, data, nodes} <- [{"[x]", ["x"], 2}, {"a: 1", %{"a" => 1}, 3}] do
      assert {:ok, ^data} = Formata.decode(input, :yaml, max_depth: 1, max_nodes: nodes)
      assert {:ok, _yaml} = Formata.encode(data, :yaml, max_depth: 1, max_nodes: nodes)

      assert {:error, [%Error{code: :limit_exceeded, details: %{limit: :max_depth, max: 0}}]} =
               Formata.decode(input, :yaml, max_depth: 0)

      assert {:error,
              [
                %Error{
                  kind: :encode,
                  code: :limit_exceeded,
                  details: %{limit: :max_depth, max: 0}
                }
              ]} = Formata.encode(data, :yaml, max_depth: 0)

      assert {:error, [%Error{code: :limit_exceeded, details: %{limit: :max_nodes}}]} =
               Formata.decode(input, :yaml, max_nodes: nodes - 1)
    end
  end

  test "constructor budgets count aliases used as keys and never expose raw key records" do
    input = "anchor: &key [x]\n? *key\n: value"

    assert {:error,
            [
              %Error{
                code: :limit_exceeded,
                location: %{line: 2},
                path: [],
                details: %{limit: :max_nodes}
              }
            ]} = Formata.decode(input, :yaml, max_nodes: 5)

    assert {:error, [%Error{kind: :unsupported, code: :unsupported_key}]} =
             Formata.decode(input, :yaml, max_nodes: 7)

    assert {:ok, %{"anchor" => "x", "x" => 1}} =
             Formata.decode("anchor: &key x\n*key : 1", :yaml, max_nodes: 5)
  end

  test "parser nesting is bounded even in pending complex-key syntax" do
    assert {:error,
            [%Error{code: :limit_exceeded, details: %{phase: :parser, limit: :max_depth, max: 1}}]} =
             Formata.decode("? [[[x]]]\n: value", :yaml, max_depth: 1)

    assert {:error,
            [%Error{code: :limit_exceeded, details: %{phase: :parser, limit: :max_nodes, max: 3}}]} =
             Formata.decode("? [a, b, c]\n: value", :yaml, max_nodes: 3)
  end

  test "single-document policy stops at the second start before converting its content" do
    input = "a: 1\n---\n? [unsupported, key]\n: value"

    assert {:error,
            [
              %Error{
                kind: :parse,
                code: :multiple_documents,
                details: %{count: 2},
                location: %{line: 2}
              }
            ]} = Formata.decode(input, :yaml)

    assert {:ok, _} = Formata.YamlElixir.read_nodes_from_string(input)
  end

  test "limits are validated and isolated to each call" do
    for opts <- [
          [max_depth: -1],
          [max_depth: :infinity],
          [max_depth: 1.0],
          [max_nodes: 0],
          [max_nodes: :infinity],
          [unknown: 2],
          [:invalid]
        ] do
      assert {:error, [%Error{kind: :unsupported, code: :invalid_option, format: :yaml}]} =
               Formata.decode("a: 1", :yaml, opts)

      assert {:error, [%Error{kind: :unsupported, code: :invalid_option, format: :yaml}]} =
               Formata.encode(%{"a" => 1}, :yaml, opts)
    end

    assert {:error, [%Error{code: :limit_exceeded}]} =
             Formata.decode(@ladder, :yaml, max_nodes: 10)

    assert {:ok, _} = Formata.decode(@ladder, :yaml)
    assert {:ok, %{"a" => 1}} = Formata.decode("a: 1", :yaml, max_nodes: 3)
    assert {:error, [%Error{code: :limit_exceeded}]} = Formata.decode("a: 1", :yaml, max_nodes: 2)
    assert {:ok, %{"a" => 1}} = Formata.decode("a: 1", :yaml)
  end

  test "encoder verification honors caller depth limits above the default" do
    data = Enum.reduce(1..130, "leaf", fn _, acc -> [acc] end)

    assert {:ok, yaml} = Formata.encode(data, :yaml, max_depth: 130, max_nodes: 131)
    assert {:ok, ^data} = Formata.decode(yaml, :yaml, max_depth: 130, max_nodes: 131)

    assert {:error,
            [
              %Error{
                kind: :encode,
                code: :limit_exceeded,
                details: %{limit: :max_depth, max: 128, actual: 129}
              }
            ]} =
             Formata.encode(data, :yaml)
  end

  test "raw C0 controls are structured syntax errors in plain and quoted flow scalars" do
    for control <- 0..31,
        control not in [9, 10, 13],
        {prefix, suffix, column} <- [{"a: x", "", 5}, {"a: \"", "\"", 5}, {"a: '", "'", 5}] do
      assert_parse_error(prefix <> <<control>> <> suffix, :invalid_character, column)
    end

    for input <- ["a: \"x\ty\"", "a: 'x\ty'", "a: x\ty"] do
      assert {:ok, %{"a" => "x\ty"}} = Formata.decode(input, :yaml)
    end

    for newline <- ["\n", "\r", "\r\n"] do
      assert {:ok, %{"a" => "x y"}} =
               Formata.decode("a: \"x" <> newline <> " y\"", :yaml)
    end
  end

  test "unfinished flow collections stop before constructor continuation tokens" do
    for input <- ["a: [", "[", "{", "a: {", "[a,", "a: [b,", "[a: ["] do
      assert_parse_error(input, :unfinished_flow_collection, byte_size(input) + 1)
    end

    assert_parse_error("outer:\n  a: [", :unfinished_flow_collection, 7, 2)
    assert_parse_error("a: [\n---\nb: 1", :unfinished_flow_collection, 1, 2)

    for {input, expected} <- [
          {"a: []", %{"a" => []}},
          {"a: [b,]", %{"a" => ["b"]}},
          {"a: {}", %{"a" => %{}}},
          {"[a: []]", [%{"a" => []}]}
        ] do
      assert {:ok, ^expected} = Formata.decode(input, :yaml)
    end
  end

  test "hexadecimal escapes reject a non-hex digit in every position" do
    for {prefix, width} <- [{"x", 2}, {"u", 4}, {"U", 8}], position <- 0..(width - 1) do
      digits =
        String.duplicate("0", position) <> "q" <> String.duplicate("0", width - position - 1)

      input = "a: \"\\" <> prefix <> digits <> "\""
      assert_parse_error(input, :invalid_escaped_character, 5)
    end

    assert_parse_error(~S(a: "\xq-"), :invalid_escaped_character, 5)
    assert_parse_error(~S(a: "\q"), :invalid_escaped_character, 5)
  end

  test "truncated hexadecimal escapes are structured syntax errors" do
    for input <- [~S(a: "\x), ~S(a: "\u12), ~S(a: "\U000012)] do
      assert_parse_error(input, :unexpected_eos, 6)
    end
  end

  test "escaped Unicode rejects isolated low surrogates and out-of-range values" do
    for escape <- ["uDC00", "uDFFF", "U0000DC00", "U0000DFFF", "U00110000", "UFFFFFFFF"] do
      assert_parse_error("a: \"\\" <> escape <> "\"", :invalid_escaped_character, 5)
    end
  end

  test "a high surrogate must be followed immediately by a low surrogate escape" do
    for continuation <- [
          ~S(\u0041\uDC00),
          ~S(\uD800\uDC00),
          ~S(\U00110000),
          ~S(\n\uDC00),
          ~S(\x41\uDC00)
        ] do
      assert_parse_error(~S(a: "\uD800) <> continuation <> "\"", :invalid_surrogate_pair, 11)
    end

    assert_parse_error(~S(a: "\uD800"), :invalid_surrogate_pair, 11)
  end

  test "valid escapes retain Unicode boundaries, controls and existing surrogate pairs" do
    for {escape, expected} <- [
          {~S(\x00\x7F\xFf), <<0, 127, 255::utf8>>},
          {~S(\u0000\uD7FF\uE000\uFFFF), <<0, 0xD7FF::utf8, 0xE000::utf8, 0xFFFF::utf8>>},
          {~S(\U00010000\U0010FFFF), <<0x10000::utf8, 0x10FFFF::utf8>>},
          {~S(\uD800\uDC00\uDBFF\uDFFF), <<0x10000::utf8, 0x10FFFF::utf8>>},
          {~S(\U0000D800\U0000DC00), <<0x10000::utf8>>},
          {~S(\0\a\b\t\n\v\f\r\e\N\_\L\P\ \"\/\\),
           <<0, 7, 8, 9, 10, 11, 12, 13, 27, 0x85::utf8, 0xA0::utf8, 0x2028::utf8, 0x2029::utf8,
             32, 34, 47, 92>>}
        ] do
      input = "a: \"" <> escape <> "\""
      assert {:ok, %{"a" => ^expected}} = Formata.decode(input, :yaml)
      assert {:ok, %{"a" => ^expected}} = Formata.YamlElixir.read_from_string(input)
      assert [[{~c"a", value}]] = :formata_yamerl_constr.string(input)
      assert List.to_string(value) == expected
    end
  end

  test "chunk boundaries preserve escape validation and Unicode pair state" do
    for input <- [~S(a: "\x0q"), ~S(a: "\u00q0"), ~S(a: "\U0000000q"), ~S(a: "\U00110000")],
        split <- 1..(byte_size(input) - 1) do
      first = binary_part(input, 0, split)
      rest = binary_part(input, split, byte_size(input) - split)

      assert {:formata_yamerl_exception,
              [{:formata_yamerl_parsing_error, :error, _, 1, 5, :invalid_escaped_character, _, _}]} =
               catch_throw(parse_chunks(first, rest))
    end

    input = ~S(a: "\uD800\uDC00")

    for split <- 1..(byte_size(input) - 1) do
      first = binary_part(input, 0, split)
      rest = binary_part(input, split, byte_size(input) - split)
      assert elem(parse_chunks(first, rest), 0) == :formata_yamerl_parser
    end
  end

  defp assert_parse_error(input, type, column, line \\ 1) do
    assert {:error,
            [
              %Error{
                kind: :parse,
                code: :syntax,
                location: %{line: ^line, column: ^column},
                details: %{type: ^type}
              }
            ]} =
             Formata.decode(input, :yaml)

    assert {:error, %Formata.YamlElixir.ParsingError{type: ^type, line: ^line, column: ^column}} =
             Formata.YamlElixir.read_nodes_from_string(input)

    assert {:formata_yamerl_exception,
            [{:formata_yamerl_parsing_error, :error, _, ^line, ^column, ^type, _, _}]} =
             catch_throw(:formata_yamerl_parser.string(input))
  end

  defp parse_chunks(first, rest) do
    {:continue, parser} =
      :formata_yamerl_parser.next_chunk(:formata_yamerl_parser.new(:test), first)

    :formata_yamerl_parser.last_chunk(parser, rest)
  end

  defp indent(input), do: input |> String.split("\n") |> Enum.map_join("\n", &("  " <> &1))
end
