defmodule Formata.Codec.TOMLBoundaryTest do
  use ExUnit.Case, async: true

  alias Formata.Error
  alias Formata.TOML.Lexer

  test "comments cannot supply an assignment's missing value across a newline" do
    for input <- comment_invalid_cases() do
      assert_invalid(input)
    end

    for {input, expected} <- comment_valid_cases() do
      assert_valid(input, expected)
    end

    for newline <- ["\n", "\r\n"] do
      assert {:error, [%Error{location: %{line: 1, column: 12}}]} =
               Formata.decode("a = # comment" <> newline <> "1", :toml)

      # A bare newline token is positioned at column zero of the next line.
      assert {:error, [%Error{location: %{line: 2, column: 0}}]} =
               Formata.decode("a =" <> newline <> "1", :toml)
    end
  end

  test "numeric underscores have digits on both sides before normalization" do
    for input <- number_invalid_cases() do
      assert_invalid(input)
    end

    for {input, expected} <- number_valid_cases() do
      assert_valid(input, expected)
    end
  end

  test "datetime separators and date-only terminators retain their grammar" do
    for input <- datetime_invalid_cases() do
      assert_invalid(input)
    end

    for {input, expected} <- datetime_valid_cases() ++ date_valid_cases() do
      assert_valid(input, expected)
    end
  end

  test "whitespace tokens retain the exact datetime separator" do
    for whitespace <- [" ", "\t", "  ", " \t", "\t "] do
      {:ok, lexer} = Lexer.new(whitespace)

      try do
        assert {:ok, {:whitespace, _, ^whitespace, _}} = Lexer.pop(lexer)
      after
        Lexer.stop(lexer)
      end
    end
  end

  test "comment tokens leave LF and CRLF as explicit grammar boundaries" do
    for newline <- ["\n", "\r\n"] do
      {:ok, lexer} = Lexer.new("# comment" <> newline <> "1")

      try do
        assert {:ok, {:comment, 9, 8, 1}} = Lexer.pop(lexer)
        assert {:ok, {:newline, _, _, 2}} = Lexer.pop(lexer)
        assert {:ok, {:digits, _, "1", 2}} = Lexer.pop(lexer)
      after
        Lexer.stop(lexer)
      end
    end
  end

  @python_skip (case System.find_executable("python3") do
                  nil ->
                    "python3 not found on PATH"

                  python ->
                    case System.cmd(python, ["-I", "-c", "import tomllib"],
                           stderr_to_stdout: true
                         ) do
                      {_, 0} -> false
                      _ -> "python3 lacks tomllib (requires Python >= 3.11)"
                    end
                end)

  if @python_skip, do: @tag(skip: @python_skip)
  @tag :python
  test "bounded decoder boundary cases agree with independent tomllib" do
    valid =
      comment_valid_cases() ++
        number_valid_cases() ++ datetime_valid_cases() ++ date_valid_cases()

    invalid = comment_invalid_cases() ++ number_invalid_cases() ++ datetime_invalid_cases()
    inputs = Enum.map(valid, &elem(&1, 0)) ++ invalid

    # These cases stay in Python's representable year/range domain (no year
    # 0000, leap second, or overflowing float). Both parsers truncate fractional
    # seconds to microseconds. Normalize UTC offsets and special float atoms;
    # neither the original timezone offset nor a NaN sign is Formata data.
    script = ~S"""
    import datetime, json, math, sys, tomllib

    # Python 3.15+ implements TOML 1.1, whose inline tables may contain
    # comments/newlines. Probe that specific extension; Formata's authority
    # remains TOML 1.0 and it must reject these two documents below.
    try:
        tomllib.loads("a = { k = 1, # comment\nj = 2 }")
        inline_comments = True
    except tomllib.TOMLDecodeError:
        inline_comments = False

    def normalize(v):
        if isinstance(v, datetime.datetime):
            if v.tzinfo is not None:
                v = v.astimezone(datetime.timezone.utc)
                kind = "datetime"
            else:
                kind = "datetime-local"
            return [kind, v.year, v.month, v.day, v.hour, v.minute, v.second, v.microsecond]
        if isinstance(v, datetime.date):
            return ["date", v.year, v.month, v.day]
        if isinstance(v, float) and not math.isfinite(v):
            return ["float", "nan" if math.isnan(v) else "inf" if v > 0 else "-inf"]
        if isinstance(v, dict):
            return {k: normalize(x) for k, x in v.items()}
        if isinstance(v, list):
            return [normalize(x) for x in v]
        return v

    results = []
    for text in json.loads(sys.argv[1]):
        try:
            results.append({"ok": normalize(tomllib.loads(text))})
        except tomllib.TOMLDecodeError:
            results.append({"error": "syntax"})
    json.dump({"inline_comments": inline_comments, "results": results}, sys.stdout)
    """

    {output, status} =
      System.cmd(System.find_executable("python3"), [
        "-I",
        "-c",
        script,
        Formata.JSON.Backend.encode!(inputs)
      ])

    assert status == 0, output

    %{"inline_comments" => inline_comments, "results" => results} =
      Formata.JSON.Backend.decode!(output)

    assert length(results) == length(inputs)
    {valid_results, invalid_results} = Enum.split(results, length(valid))

    for {{input, expected}, result} <- Enum.zip(valid, valid_results) do
      assert result == %{"ok" => normalize(expected)}, input
      assert_valid(input, expected)
    end

    for {input, result} <- Enum.zip(invalid, invalid_results) do
      if inline_comments and input in inline_comment_cases() do
        assert result == %{"ok" => %{"a" => %{"k" => 1, "j" => 2}}}, input
      else
        assert result == %{"error" => "syntax"}, input
      end

      # Every invalid case stays rejected by both Formata APIs, including the
      # two TOML 1.1 reference extensions. No conformance exclusions are added.
      assert_invalid(input)
    end
  end

  defp assert_valid(input, expected) do
    assert {:ok, ^expected} = Formata.TOML.decode(input), input
    assert {:ok, ^expected} = Formata.decode(input, :toml), input
  end

  defp assert_invalid(input) do
    assert {:error, {:invalid_toml, message}} = Formata.TOML.decode(input), input
    assert is_binary(message)

    assert {:error,
            [
              %Error{
                kind: :parse,
                code: :syntax,
                path: [],
                backend: Formata.TOML,
                format: :toml,
                location: %{line: line, column: column}
              }
            ]} = Formata.decode(input, :toml),
           input

    assert line >= 1
    assert column >= 0
  end

  defp comment_invalid_cases do
    for newline <- ["\n", "\r\n"],
        whitespace <- ["", " ", "\t"],
        {prefix, suffix} <- [{"a =", "1"}, {"a = { k =", "1 }"}] do
      prefix <> whitespace <> "# comment" <> newline <> suffix
    end ++
      ["a = # EOF", "a = { k = # EOF"] ++
      for newline <- ["\n", "\r\n"],
          {prefix, suffix} <- [{"a =", "1"}, {"a = { k =", "1 }"}] do
        prefix <> newline <> suffix
      end ++
      inline_comment_cases()
  end

  defp inline_comment_cases do
    for newline <- ["\n", "\r\n"] do
      "a = { k = 1, # comment" <> newline <> "j = 2 }"
    end
  end

  defp comment_valid_cases do
    for newline <- ["\n", "\r\n"],
        {text, expected} <- [
          {"a = [# first\n1, # between\n2 # last\n]", %{"a" => [1, 2]}},
          {"a = 1 # trailing\nb = 2 # EOF", %{"a" => 1, "b" => 2}},
          {"# only comment", %{}},
          {"a = { k = [# nested array\n1,\n2\n] }", %{"a" => %{"k" => [1, 2]}}},
          {"a = { k = \"\"\"first\nsecond\"\"\" }", %{"a" => %{"k" => "first\nsecond"}}},
          {"a = { k = '''first\nsecond''' }", %{"a" => %{"k" => "first\nsecond"}}}
        ] do
      {String.replace(text, "\n", newline), expected}
    end
  end

  defp number_invalid_cases do
    exponent =
      for mantissa <- ["1", "1.0"],
          marker <- ["e", "E"],
          sign <- ["", "+", "-"],
          digits <- ["", "_2", "2_", "2__3"] do
        "a = " <> mantissa <> marker <> sign <> digits
      end

    other =
      for sign <- ["", "+", "-"],
          number <- ["_1", "1_", "1__0", "1_.0", "1._0", "1.0_", "1.0__1", "1.", "1.e2"] do
        "a = " <> sign <> number
      end

    for input <- exponent ++ other,
        {prefix, suffix} <- [{"a = ", ""}, {"a = [", "]"}, {"a = { k = ", "}"}] do
      prefix <> String.replace_prefix(input, "a = ", "") <> suffix
    end
  end

  defp number_valid_cases do
    finite =
      for sign <- ["", "+", "-"],
          {number, value} <- [
            {"1e+1_0", 1.0e10},
            {"1E-1_0", 1.0e-10},
            {"1_000.5", 1000.5},
            {"1.0e-2", 0.01},
            {"1.2_5E+0_2", 125.0},
            {"1_000", 1000}
          ] do
        expected = if sign == "-", do: -value, else: value
        {"a = " <> sign <> number, %{"a" => expected}}
      end

    finite ++
      [
        {"a = +inf", %{"a" => :infinity}},
        {"a = -inf", %{"a" => :negative_infinity}},
        {"a = -nan", %{"a" => :nan}}
      ]
  end

  defp datetime_invalid_cases do
    for separator <- ["\t", "  ", " \t", "\t "],
        offset <- ["", "Z", "+05:30", "-08:00"],
        {prefix, suffix} <- [{"d = ", ""}, {"d = [", "]"}, {"a = {d = ", "}"}] do
      prefix <> "2024-01-01" <> separator <> "12:00:00" <> offset <> suffix
    end
  end

  defp datetime_valid_cases do
    for separator <- ["T", "t", " "],
        {offset, value} <- [
          {"", ~N[2024-01-01 12:00:00.123456]},
          {"Z", ~U[2024-01-01 12:00:00.123456Z]},
          {"z", ~U[2024-01-01 12:00:00.123456Z]},
          {"+05:30", ~U[2024-01-01 06:30:00.123456Z]},
          {"-08:00", ~U[2024-01-01 20:00:00.123456Z]}
        ],
        {prefix, suffix, wrap} <- contexts() do
      {prefix <> "2024-01-01" <> separator <> "12:00:00.123456789" <> offset <> suffix,
       wrap.(value)}
    end
  end

  defp date_valid_cases do
    for whitespace <- ["", " ", "  ", "\t", " \t"],
        {prefix, suffix, wrap} <- contexts() do
      {prefix <> "2024-01-01" <> whitespace <> suffix, wrap.(~D[2024-01-01])}
    end
  end

  defp contexts do
    [
      {"d = ", "", &%{"d" => &1}},
      {"d = ", " \t", &%{"d" => &1}},
      {"d = ", " # trailing\r\n", &%{"d" => &1}},
      {"d = [", "]", &%{"d" => [&1]}},
      {"d = [", ", 1]", &%{"d" => [&1, 1]}},
      {"a = {d = ", "}", &%{"a" => %{"d" => &1}}},
      {"a = {d = ", ", x = 1}", &%{"a" => %{"d" => &1, "x" => 1}}}
    ]
  end

  defp normalize(%DateTime{} = value) do
    value = DateTime.shift_zone!(value, "Etc/UTC")
    temporal("datetime", value)
  end

  defp normalize(%NaiveDateTime{} = value), do: temporal("datetime-local", value)
  defp normalize(%Date{} = value), do: ["date", value.year, value.month, value.day]
  defp normalize(:infinity), do: ["float", "inf"]
  defp normalize(:negative_infinity), do: ["float", "-inf"]
  defp normalize(:nan), do: ["float", "nan"]
  defp normalize(value) when is_map(value), do: Map.new(value, fn {k, v} -> {k, normalize(v)} end)
  defp normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)
  defp normalize(value), do: value

  defp temporal(kind, value) do
    [
      kind,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      elem(value.microsecond, 0)
    ]
  end
end
