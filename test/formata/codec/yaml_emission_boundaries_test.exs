defmodule Formata.Codec.YAMLEmissionBoundariesTest do
  use ExUnit.Case, async: true

  defp contexts(value) do
    [
      value,
      %{"v" => value},
      [value],
      [value, "after"],
      ["before", value],
      %{"nested" => [%{"v" => value}]},
      [[value], ["after"]]
    ]
  end

  defp assert_roundtrip(data) do
    for encode <- [&Formata.Ymlr.document/1, &Formata.encode(&1, :yaml)] do
      assert {:ok, yaml} = encode.(data)
      assert {:ok, ^data} = Formata.decode(yaml, :yaml)
      assert :binary.match(yaml, <<0>>) == :nomatch
    end
  end

  test "root null is emitted as YAML null while the string nil stays a string" do
    assert {:ok, "---\nnull\n"} = Formata.Ymlr.document(nil)
    assert {:ok, "---\nnull\n"} = Formata.encode(nil, :yaml)

    for value <- [nil, "nil", "", [], %{}, true, false, 42, 0.5], data <- contexts(value) do
      assert_roundtrip(data)
    end
  end

  test "the reported multiline values preserve spaces CRLF and controls in every context" do
    for value <- [" a\nb", " a\n b", "a\r\nb", "a\n\u0000"], data <- contexts(value) do
      assert_roundtrip(data)
    end
  end

  test "deterministic whitespace and escape boundaries preserve string contents" do
    for prefix <- ["", " ", "\t", "\n", "\n  "],
        body <- ["a", "a\nb", "a\n b", "a\r\nb", "a\n\u0000", "a\\\"\nb"],
        suffix <- ["", "\n", "\n\n", " ", " \n", "\n \n"],
        data <- contexts(prefix <> body <> suffix) do
      assert_roundtrip(data)
    end
  end

  test "implicit scalar lookalikes are encoded as strings" do
    for value <- [
          ".5",
          "+.5",
          "-.5",
          "1.",
          "1.e2",
          "1e+2",
          "1.7976931348623157e+309",
          "null",
          "true",
          "false",
          ".nan",
          "-.inf",
          "0xFF",
          "0o77",
          "---",
          "...",
          "--- value",
          "...\tvalue",
          "-\tvalue",
          "?\tvalue",
          ":\tvalue",
          "value:\tother",
          "value\t#comment"
        ],
        data <- contexts(value) do
      assert_roundtrip(data)
    end
  end

  test "double-quoted multiline strings escape controls and Unicode separators" do
    characters =
      Enum.to_list(0..31) ++
        [0x7F, 0x80, 0x85, 0x9F, 0xA0, 0x2028, 0x2029, 0xFEFF, 0xFFFE, 0xFFFF, 0x1F600]

    for char <- characters, data <- contexts("a\n" <> <<char::utf8>> <> "b") do
      assert_roundtrip(data)
    end
  end

  test "a byte-order-mark character is preserved as string content" do
    for value <- ["\uFEFF", "\uFEFFx", "x\uFEFF"], data <- contexts(value) do
      assert_roundtrip(data)
    end
  end

  test "string keys use YAML escapes and quote the literal merge-looking key" do
    for key <- [
          "<<",
          ".5",
          "",
          "\uFEFF",
          "a\nb",
          "\n leading \n",
          "a\n\u0000",
          "a\n\"\\\u001F",
          "雪😀"
        ],
        data <- [%{key => "value"}, %{"nested" => [%{key => "value"}]}] do
      assert_roundtrip(data)
    end

    assert {:ok, yaml} = Formata.encode(%{"<<" => 1}, :yaml)
    assert yaml =~ "'<<': 1"
  end
end
