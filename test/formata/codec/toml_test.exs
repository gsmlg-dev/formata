defmodule Formata.Codec.TOMLTest do
  use ExUnit.Case, async: true

  alias Formata.Error

  doctest Formata.Codec.TOML.Encoder

  # 2024-02-29T17:30:00+05:30 == 2024-02-29T12:00:00Z
  defp ist do
    %DateTime{
      year: 2024,
      month: 2,
      day: 29,
      hour: 17,
      minute: 30,
      second: 0,
      microsecond: {0, 0},
      utc_offset: 19_800,
      std_offset: 0,
      time_zone: "Asia/Kolkata",
      zone_abbr: "IST"
    }
  end

  defp roundtrip(data) do
    assert {:ok, toml} = Formata.encode(data, :toml)
    assert {:ok, decoded} = Formata.TOML.decode(toml)
    {toml, decoded}
  end

  describe "decode" do
    test "decodes the TOML value domain" do
      input = """
      title = "x"
      n = 1
      f = 1.5
      pinf = inf
      ninf = -inf
      nan = nan
      d = 1979-05-27
      t = 07:32:00
      ldt = 1979-05-27T07:32:00
      odt = 1979-05-27T07:32:00-08:00

      [[items]]
      id = 1

      [[items]]
      id = 2
      """

      assert {:ok, data} = Formata.decode(input, :toml)

      assert %{
               "title" => "x",
               "n" => 1,
               "f" => 1.5,
               "pinf" => :infinity,
               "ninf" => :negative_infinity,
               "nan" => :nan,
               "d" => ~D[1979-05-27],
               "t" => ~T[07:32:00],
               "ldt" => ~N[1979-05-27 07:32:00],
               "items" => [%{"id" => 1}, %{"id" => 2}]
             } = data

      assert %DateTime{time_zone: "Etc/UTC"} = data["odt"]
    end

    # Regression: gsmlg-dev/gsmlg_umbrella#13 (offset sign was inverted).
    test "offset date-times decode to the correct instant" do
      assert {:ok, %{"odt" => odt}} = Formata.decode("odt = 1979-05-27T07:32:00-08:00", :toml)
      assert DateTime.compare(odt, ~U[1979-05-27 15:32:00Z]) == :eq

      assert {:ok, %{"odt" => odt}} = Formata.decode("odt = 2024-02-29T17:30:00+05:30", :toml)
      assert DateTime.compare(odt, ~U[2024-02-29 12:00:00Z]) == :eq

      assert {:ok, %{"a" => ~U[1979-05-27 14:32:00Z]}} =
               Formata.TOML.decode("a = 1979-05-27T07:32:00-07:00")

      assert {:error, _} = Formata.TOML.decode("a = 1979-05-27T07:32:00+24:00")
      assert {:error, _} = Formata.TOML.decode("a = 1979-05-27T07:32:00+00:60")
    end

    # Regression: gsmlg-dev/gsmlg_umbrella#14 (empty elements were dropped).
    test "empty array-of-tables elements and their subtables are kept" do
      assert {:ok, %{"a" => [%{}, %{"x" => 1}]}} = Formata.TOML.decode("[[a]]\n[[a]]\nx = 1")
      assert {:ok, %{"a" => [%{}]}} = Formata.TOML.decode("[[a]]")
      assert {:ok, %{"a" => [%{}, %{}, %{}]}} = Formata.TOML.decode("[[a]]\n[[a]]\n[[a]]\n")

      assert {:ok, %{"a" => [%{"b" => %{"c" => 1}}, %{}]}} =
               Formata.TOML.decode("[[a]]\n[a.b]\nc = 1\n[[a]]\n")

      assert {:ok, %{"a" => [%{"b" => [%{}]}, %{"b" => [%{}, %{"y" => 2}]}]}} =
               Formata.TOML.decode("[[a]]\n[[a.b]]\n[[a]]\n[[a.b]]\n[[a.b]]\ny = 2\n")
    end

    # Regression: gsmlg-dev/gsmlg_umbrella#15 (bare keys `true`/`false` were rejected).
    test "true and false are valid bare keys" do
      assert {:ok, %{"true" => 1, "false" => 2}} = Formata.TOML.decode("true = 1\nfalse = 2")
      assert {:ok, %{"false" => false}} = Formata.TOML.decode("false = false")
      assert {:ok, %{"true" => %{"false" => true}}} = Formata.TOML.decode("[true]\nfalse = true")
      assert {:ok, %{"a" => %{"true" => %{"x" => 1}}}} = Formata.TOML.decode("a.true.x = 1")
      assert {:ok, %{"t" => %{"true" => 1}}} = Formata.TOML.decode("t = { true = 1 }")
      assert {:ok, %{"true-ish" => 1}} = Formata.TOML.decode("true-ish = 1")
      assert {:error, _} = Formata.TOML.decode("a = truex")
    end

    # Regression: gsmlg-dev/gsmlg_umbrella#16 (local date-time before `,` crashed).
    test "local date-times are delimited by array and inline-table punctuation" do
      assert {:ok, %{"a" => [~N[1979-05-27 07:32:00], 1]}} =
               Formata.TOML.decode("a = [1979-05-27T07:32:00, 1]")

      assert {:ok, %{"a" => [~N[1979-05-27 07:32:00], ~D[2006-06-01]]}} =
               Formata.TOML.decode("a = [1979-05-27T07:32:00,2006-06-01]")

      assert {:ok, %{"a" => [~N[1979-05-27 07:32:00]]}} =
               Formata.TOML.decode("a = [1979-05-27T07:32:00]")

      assert {:ok, %{"t" => %{"d" => ~N[1979-05-27 07:32:00], "x" => 1}}} =
               Formata.TOML.decode("t = { d = 1979-05-27T07:32:00, x = 1 }")

      assert {:ok, %{"t" => %{"d" => ~N[1979-05-27 07:32:00]}}} =
               Formata.TOML.decode("t = {d = 1979-05-27T07:32:00}")
    end

    test "decoder errors are returned, not raised, for invalid UTF-8 and escapes" do
      assert {:error, [%Error{kind: :parse}]} = Formata.decode("a = 1\n\xDA", :toml)
      assert {:error, [%Error{kind: :parse}]} = Formata.decode(~S(a = "\U0000000"), :toml)
      assert {:error, [%Error{kind: :parse}]} = Formata.decode(~S(a = "\uD800"), :toml)
      assert {:error, [%Error{kind: :parse}]} = Formata.decode(~S(a = "\d"), :toml)
    end

    test "duplicate keys and malformed input are parse errors" do
      assert {:error, [%Error{kind: :parse, code: :syntax, backend: Formata.TOML}]} =
               Formata.decode("a = 1\na = 2\n", :toml)

      # Line/column come from the decoder's own report.
      assert {:error, [%Error{kind: :parse, location: %{line: line, column: 5}}]} =
               Formata.decode("x = 1\na = \n", :toml)

      assert line in 2..3
    end
  end

  describe "encode" do
    test "nested tables and mixed table/scalar nesting" do
      data = %{
        "name" => "app",
        "server" => %{
          "host" => "localhost",
          "port" => 8080,
          "tls" => %{"enabled" => true},
          "limits" => %{"rate" => %{"burst" => 10}}
        }
      }

      {toml, decoded} = roundtrip(data)
      assert decoded == data

      assert toml == """
             name = "app"

             [server]
             host = "localhost"
             port = 8080

             [server.limits]

             [server.limits.rate]
             burst = 10

             [server.tls]
             enabled = true
             """
    end

    test "arrays of tables, including nested tables and arrays inside elements" do
      data = %{
        "fruits" => [
          %{
            "name" => "apple",
            "physical" => %{"color" => "red"},
            "varieties" => [%{"name" => "red delicious"}, %{"name" => "granny smith"}]
          },
          %{"name" => "banana", "varieties" => [%{"name" => "plantain"}]},
          %{}
        ]
      }

      {toml, decoded} = roundtrip(data)
      assert decoded == data
      assert toml =~ "[[fruits]]\nname = \"apple\""
      assert toml =~ "[fruits.physical]\ncolor = \"red\""
      assert toml =~ "[[fruits.varieties]]\nname = \"granny smith\""
    end

    test "dates and times" do
      data = %{
        "d" => ~D[2024-02-29],
        "t" => ~T[23:59:59.123456],
        "ldt" => ~N[2024-02-29 12:00:00.5],
        "utc" => ~U[2024-02-29 12:00:00Z]
      }

      {toml, decoded} = roundtrip(data)
      assert decoded == data
      assert toml =~ "d = 2024-02-29\n"
      assert toml =~ "utc = 2024-02-29T12:00:00Z\n"

      assert {:ok, "at = 2024-02-29T17:30:00+05:30\n"} = Formata.encode(%{"at" => ist()}, :toml)
    end

    test "offset date-times round-trip to the same instant" do
      assert {:ok, toml} = Formata.encode(%{"at" => ist()}, :toml)
      assert {:ok, %{"at" => back}} = Formata.decode(toml, :toml)
      assert DateTime.compare(back, ist()) == :eq
    end

    test "empty collections" do
      data = %{
        "empty_list" => [],
        "empty_table" => %{},
        "nested" => %{"inner" => %{}},
        "lists" => [[], [[]]]
      }

      {_toml, decoded} = roundtrip(data)
      assert decoded == data
    end

    test "string escaping and quoted keys" do
      data = %{
        "quote" => ~s(say "hi"),
        "backslash" => ~S(C:\path),
        "controls" => "tab\there\nnew\rline\b\f\u0001\u007F",
        "unicode" => "héllo ☃ 😀",
        "a.b" => 1,
        "" => "empty key",
        "spaced key" => %{"ü" => true},
        "list" => ["a\"b", "\\"]
      }

      {toml, decoded} = roundtrip(data)
      assert decoded == data
      assert toml =~ ~S("a.b" = 1)
      assert toml =~ ~S("" = "empty key")
      assert toml =~ ~S(["spaced key"])
      assert toml =~ ~S(\u0001)
    end

    test "integers, floats and special floats" do
      data = %{
        "max" => 9_223_372_036_854_775_807,
        "min" => -9_223_372_036_854_775_808,
        "f" => 1.0,
        "neg_zero" => -0.0,
        "tiny" => 1.0e-300,
        "big" => 1.7976931348623157e308,
        "inf" => :infinity,
        "ninf" => :negative_infinity,
        "nan" => :nan
      }

      {_toml, decoded} = roundtrip(data)
      assert decoded == data
      assert decoded["neg_zero"] === -0.0
    end

    test "lists that mix tables and scalars become inline arrays" do
      data = %{
        "mixed" => [1, %{"a" => %{"b" => [2]}}, "x"],
        "tables" => %{"inline" => [[%{"x" => 1}]]}
      }

      {toml, decoded} = roundtrip(data)
      assert decoded == data
      assert toml =~ ~S(mixed = [1, { a = { b = [2] } }, "x"])
    end

    test "rejects nil instead of dropping it" do
      assert {:error,
              [%Error{kind: :encode, code: :unrepresentable, path: ["a", "b"], format: :toml}]} =
               Formata.encode(%{"a" => %{"b" => nil}}, :toml)

      assert {:error, [%Error{path: ["l", 1]}]} = Formata.encode(%{"l" => [1, nil]}, :toml)
    end

    test "rejects roots, keys and values outside the domain" do
      assert {:error, [%Error{code: :invalid_root}]} = Formata.encode([1], :toml)
      assert {:error, [%Error{code: :invalid_root}]} = Formata.encode("x", :toml)
      assert {:error, [%Error{code: :invalid_root}]} = Formata.encode(~D[2024-01-01], :toml)
      assert {:error, [%Error{code: :invalid_key}]} = Formata.encode(%{a: 1}, :toml)
      assert {:error, [%Error{code: :unrepresentable}]} = Formata.encode(%{"x" => :foo}, :toml)
      assert {:error, [%Error{code: :unrepresentable}]} = Formata.encode(%{"x" => {1}}, :toml)

      assert {:error, [%Error{code: :unrepresentable}]} =
               Formata.encode(%{"x" => %URI{host: "h"}}, :toml)

      assert {:error, [%Error{code: :out_of_range}]} =
               Formata.encode(%{"x" => 9_223_372_036_854_775_808}, :toml)

      assert {:error, [%Error{code: :unrepresentable}]} =
               Formata.encode(%{"x" => Date.new!(10_000, 1, 1)}, :toml)

      assert {:error, [%Error{code: :unrepresentable}]} =
               Formata.encode(%{"x" => <<0xFF>>}, :toml)
    end
  end
end
