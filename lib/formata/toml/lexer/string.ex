defmodule Formata.TOML.Lexer.String do
  @moduledoc false

  # This module manages the complexity of lexing quoted and literal
  # strings as defined by the TOML spec.

  import Formata.TOML.Lexer.Guards

  @type type ::
          :string
          | :multiline_string

  @type skip :: Formata.TOML.Lexer.skip()
  @type lines :: Formata.TOML.Lexer.lines()
  @type lexer_err :: Formata.TOML.Lexer.lexer_err()
  @type result :: {:ok, binary, {type, skip, binary, lines}} | lexer_err

  @spec lex(binary, skip, lines) :: result
  def lex(binary, skip, lines)

  def lex(<<>>, skip, lines),
    do: {:error, :unexpected_eof, skip, lines}

  def lex(<<?\', ?\', ?\', rest::binary>>, skip, lines) do
    {rest, skip, lines} = trim_newline(rest, skip + 3, lines)
    lex_literal(:multi, rest, skip, [], lines)
  end

  def lex(<<?\', ?\', rest::binary>>, skip, lines),
    do: {:ok, rest, {:string, skip + 2, <<>>, lines}}

  def lex(<<?\', rest::binary>>, skip, lines),
    do: lex_literal(:single, rest, skip + 1, [], lines)

  def lex(<<?\", ?\", ?\", rest::binary>>, skip, lines) do
    {rest, skip, lines} = trim_newline(rest, skip + 3, lines)
    lex_quoted(:multi, rest, skip, [], lines)
  end

  def lex(<<?\", ?\", rest::binary>>, skip, lines),
    do: {:ok, rest, {:string, skip + 2, <<>>, lines}}

  def lex(<<?\", rest::binary>>, skip, lines),
    do: lex_quoted(:single, rest, skip + 1, [], lines)

  defp lex_literal(_type, <<>>, skip, _acc, lines),
    do: {:error, :unclosed_quote, skip, lines}

  # Disallow newlines in single-line literals
  defp lex_literal(:single, <<?\r, ?\n, _::binary>>, skip, _acc, lines),
    do: {:error, :unexpected_newline, skip + 1, lines}

  defp lex_literal(:single, <<?\n, _::binary>>, skip, _acc, lines),
    do: {:error, :unexpected_newline, skip + 1, lines}

  defp lex_literal(type, <<?\r, ?\n, rest::binary>>, skip, acc, lines),
    do: lex_literal(type, rest, skip + 2, [?\n | acc], lines + 1)

  defp lex_literal(type, <<?\n, rest::binary>>, skip, acc, lines),
    do: lex_literal(type, rest, skip + 1, [?\n | acc], lines + 1)

  # Closing quotes
  defp lex_literal(:single, <<?\', rest::binary>>, skip, acc, lines) do
    bin = acc |> Enum.reverse() |> IO.chardata_to_string()
    {:ok, rest, {:string, skip + 1, bin, lines}}
  end

  # Up to two quotes may directly precede the closing delimiter
  defp lex_literal(:multi, <<?\', ?\', ?\', ?\', ?\', rest::binary>>, skip, acc, lines),
    do: multiline(rest, skip + 5, [?\', ?\' | acc], lines)

  defp lex_literal(:multi, <<?\', ?\', ?\', ?\', rest::binary>>, skip, acc, lines),
    do: multiline(rest, skip + 4, [?\' | acc], lines)

  defp lex_literal(:multi, <<?\', ?\', ?\', rest::binary>>, skip, acc, lines),
    do: multiline(rest, skip + 3, acc, lines)

  # Disallow any control chars in literals, EXCEPT \t
  defp lex_literal(type, <<?\t, rest::binary>>, skip, acc, lines),
    do: lex_literal(type, rest, skip + 1, [?\t | acc], lines)

  defp lex_literal(_type, <<c::utf8, _::binary>>, skip, _acc, lines)
       when (c >= 0 and c <= 31) or c == 127,
       do: {:error, {:invalid_control_char, <<c::utf8>>}, skip + 1, lines}

  # Eat next character in string
  defp lex_literal(type, <<c::utf8, rest::binary>>, skip, acc, lines),
    do: lex_literal(type, rest, skip + 1, [c | acc], lines)

  # Invalid byte sequence (i.e. invalid unicode)
  defp lex_literal(_type, <<c, _::binary>>, skip, _acc, lines),
    do: {:error, {:invalid_unicode, <<c>>}, skip + 1, lines}

  defp lex_quoted(_type, <<>>, skip, _acc, lines),
    do: {:error, :unclosed_quote, skip, lines}

  # Disallow newlines in single-line strings
  defp lex_quoted(:single, <<?\r, ?\n, _::binary>>, skip, _acc, lines),
    do: {:error, :unexpected_newline, skip + 1, lines}

  defp lex_quoted(:single, <<?\n, _::binary>>, skip, _acc, lines),
    do: {:error, :unexpected_newline, skip + 1, lines}

  defp lex_quoted(type, <<?\r, ?\n, rest::binary>>, skip, acc, lines),
    do: lex_quoted(type, rest, skip + 2, [?\n | acc], lines + 1)

  defp lex_quoted(type, <<?\n, rest::binary>>, skip, acc, lines),
    do: lex_quoted(type, rest, skip + 1, [?\n | acc], lines + 1)

  # Line-ending backslash in multi-line strings: `\`, optional whitespace and
  # a newline; all following whitespace and newlines are trimmed.
  defp lex_quoted(:multi, <<?\\, c, rest::binary>>, skip, acc, lines)
       when c in [?\s, ?\t, ?\r, ?\n] do
    case skip_line_ending(<<c, rest::binary>>, skip + 1, lines, false) do
      {:ok, rest, skip, lines} ->
        lex_quoted(:multi, rest, skip, acc, lines)

      :error ->
        {:error, {:invalid_escape, <<?\\, c>>}, skip + 1, lines}
    end
  end

  # Allowed escapes
  defp lex_quoted(type, <<?\\, ?\\, rest::binary>>, skip, acc, lines) do
    lex_quoted(type, rest, skip + 2, [?\\ | acc], lines)
  end

  defp lex_quoted(type, <<?\\, ?b, rest::binary>>, skip, acc, lines) do
    lex_quoted(type, rest, skip + 2, [?\b | acc], lines)
  end

  defp lex_quoted(type, <<?\\, ?f, rest::binary>>, skip, acc, lines) do
    lex_quoted(type, rest, skip + 2, [?\f | acc], lines)
  end

  defp lex_quoted(type, <<?\\, ?n, rest::binary>>, skip, acc, lines) do
    lex_quoted(type, rest, skip + 2, [?\n | acc], lines)
  end

  defp lex_quoted(type, <<?\\, ?r, rest::binary>>, skip, acc, lines) do
    lex_quoted(type, rest, skip + 2, [?\r | acc], lines)
  end

  defp lex_quoted(type, <<?\\, ?t, rest::binary>>, skip, acc, lines) do
    lex_quoted(type, rest, skip + 2, [?\t | acc], lines)
  end

  defp lex_quoted(type, <<?\\, ?\", rest::binary>>, skip, acc, lines),
    do: lex_quoted(type, rest, skip + 2, [?\" | acc], lines)

  defp lex_quoted(type, <<?\\, ?u, rest::binary>>, skip, acc, lines) do
    {char, rest, skip2} = unescape_unicode(?u, rest)
    lex_quoted(type, rest, 2 + skip + skip2, [char | acc], lines)
  catch
    :throw, {:invalid_unicode, _} = reason ->
      {:error, reason, skip + 1, lines}
  end

  defp lex_quoted(type, <<?\\, ?U, rest::binary>>, skip, acc, lines) do
    {char, rest, skip2} = unescape_unicode(?U, rest)
    lex_quoted(type, rest, 2 + skip + skip2, [char | acc], lines)
  catch
    :throw, {:invalid_unicode, _} = reason ->
      {:error, reason, skip + 1, lines}
  end

  # Bad escape
  defp lex_quoted(_type, <<?\\, char::utf8, _::binary>>, skip, _acc, lines) do
    {:error, {:invalid_escape, <<?\\, char::utf8>>}, skip + 1, lines}
  end

  # Closing quotes; up to two quotes may directly precede the delimiter
  defp lex_quoted(:multi, <<?\", ?\", ?\", ?\", ?\", rest::binary>>, skip, acc, lines),
    do: multiline(rest, skip + 5, [?\", ?\" | acc], lines)

  defp lex_quoted(:multi, <<?\", ?\", ?\", ?\", rest::binary>>, skip, acc, lines),
    do: multiline(rest, skip + 4, [?\" | acc], lines)

  defp lex_quoted(:multi, <<?\", ?\", ?\", rest::binary>>, skip, acc, lines),
    do: multiline(rest, skip + 3, acc, lines)

  defp lex_quoted(:single, <<?\", rest::binary>>, skip, acc, lines) do
    bin = acc |> Enum.reverse() |> IO.chardata_to_string()
    {:ok, rest, {:string, skip + 1, bin, lines}}
  end

  # Tab is the only control character allowed unescaped
  defp lex_quoted(type, <<?\t, rest::binary>>, skip, acc, lines),
    do: lex_quoted(type, rest, skip + 1, [?\t | acc], lines)

  # Disallow any unescaped control chars in quoted strings
  defp lex_quoted(_type, <<c::utf8, _::binary>>, skip, _acc, lines)
       when (c >= 0 and c <= 31) or c == 127,
       do: {:error, {:invalid_control_char, <<c::utf8>>}, skip + 1, lines}

  # Eat next character in string
  defp lex_quoted(type, <<c::utf8, rest::binary>>, skip, acc, lines) do
    lex_quoted(type, rest, skip + 1, [c | acc], lines)
  end

  defp lex_quoted(_type, <<c, _::binary>>, skip, _acc, lines),
    do: {:error, {:invalid_unicode, <<c>>}, skip + 1, lines}

  defp multiline(rest, skip, acc, lines) do
    bin = acc |> Enum.reverse() |> IO.chardata_to_string()
    {:ok, rest, {:multiline_string, skip, bin, lines}}
  end

  defp trim_newline(<<?\r, ?\n, rest::binary>>, skip, lines), do: {rest, skip + 2, lines + 1}
  defp trim_newline(<<?\n, rest::binary>>, skip, lines), do: {rest, skip + 1, lines + 1}
  defp trim_newline(rest, skip, lines), do: {rest, skip, lines}

  # Skips the whitespace and newlines after a line-ending backslash; at least
  # one newline is required.
  defp skip_line_ending(<<c, rest::binary>>, skip, lines, nl?) when is_whitespace(c),
    do: skip_line_ending(rest, skip + 1, lines, nl?)

  defp skip_line_ending(<<?\r, ?\n, rest::binary>>, skip, lines, _nl?),
    do: skip_line_ending(rest, skip + 2, lines + 1, true)

  defp skip_line_ending(<<?\n, rest::binary>>, skip, lines, _nl?),
    do: skip_line_ending(rest, skip + 1, lines + 1, true)

  defp skip_line_ending(rest, skip, lines, true), do: {:ok, rest, skip, lines}
  defp skip_line_ending(_rest, _skip, _lines, false), do: :error

  def unescape_unicode(?U, <<n::8-binary, bin::binary>>), do: {codepoint!(n), bin, 8}
  def unescape_unicode(?u, <<n::4-binary, bin::binary>>), do: {codepoint!(n), bin, 4}
  def unescape_unicode(_type, bin), do: bad_unicode!(binary_part(bin, 0, min(byte_size(bin), 1)))

  # Escapes must be hex digits naming a Unicode scalar value
  # (0..0xD7FF or 0xE000..0x10FFFF); surrogates are not allowed.
  defp codepoint!(hex) do
    with true <- hex =~ ~r/\A[0-9A-Fa-f]+\z/,
         u = String.to_integer(hex, 16),
         true <- u <= 0xD7FF or (u >= 0xE000 and u <= 0x10FFFF) do
      <<u::utf8>>
    else
      _ -> bad_unicode!(hex)
    end
  end

  @spec bad_unicode!(binary) :: no_return
  defp bad_unicode!(byte), do: throw({:invalid_unicode, byte})
end
