defmodule Formata.Codec.JSON5.Parser do
  @moduledoc false
  # Recursive-descent parser for JSON5 1.0.0 (https://spec.json5.org/).
  #
  # Values are returned in Formata's portable domain: string keys, integers,
  # floats, `:infinity` / `:negative_infinity` / `:nan`. Duplicate keys
  # (compared after unescaping) are rejected. Failures are thrown as
  # `{__MODULE__, code, message, offset, details}` and caught by `parse/1`.

  import Bitwise, only: [<<<: 2]

  @integer_digit_limit 1024

  @spec parse(binary) ::
          {:ok, term} | {:error, atom, String.t(), non_neg_integer, map}
  def parse(input) do
    {rest, pos} = ws(input, 0)
    {value, rest, pos} = value(rest, pos, [])
    {rest, pos} = ws(rest, pos)

    case rest do
      <<>> -> {:ok, value}
      _ -> unexpected(rest, pos)
    end
  catch
    {__MODULE__, code, message, offset, details} -> {:error, code, message, offset, details}
  end

  # -- Whitespace and comments ------------------------------------------------------

  # JSON5 WhiteSpace: TAB, VT, FF, SP, NBSP, BOM, other Zs; LineTerminator: LF,
  # CR, LS, PS.
  @ws_ascii ~c"\t\n\v\f\r "
  @ws_unicode [0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF] ++
                Enum.to_list(0x2000..0x200A)

  defp ws(<<b, rest::bits>>, pos) when b in @ws_ascii, do: ws(rest, pos + 1)

  defp ws(<<c::utf8, rest::bits>>, pos) when c in @ws_unicode,
    do: ws(rest, pos + byte_size(<<c::utf8>>))

  defp ws(<<"//", rest::bits>>, pos), do: line_comment(rest, pos + 2)
  defp ws(<<"/*", rest::bits>>, pos), do: block_comment(rest, pos + 2, pos)
  defp ws(rest, pos), do: {rest, pos}

  defp line_comment(<<b, _::bits>> = rest, pos) when b in ~c"\n\r", do: ws(rest, pos)

  defp line_comment(<<c::utf8, _::bits>> = rest, pos) when c in [0x2028, 0x2029],
    do: ws(rest, pos)

  defp line_comment(<<c::utf8, rest::bits>>, pos), do: line_comment(rest, pos + utf8_size(c))
  defp line_comment(<<>>, pos), do: {<<>>, pos}
  defp line_comment(_rest, pos), do: fail("invalid UTF-8", pos)

  defp block_comment(<<"*/", rest::bits>>, pos, _start), do: ws(rest, pos + 2)

  defp block_comment(<<c::utf8, rest::bits>>, pos, start),
    do: block_comment(rest, pos + utf8_size(c), start)

  defp block_comment(<<>>, pos, start),
    do: fail("unterminated block comment starting at position #{start}", pos)

  defp block_comment(_rest, pos, _start), do: fail("invalid UTF-8", pos)

  # -- Values ------------------------------------------------------------------------

  defp value(<<"{", rest::bits>>, pos, path), do: object(rest, pos + 1, path)
  defp value(<<"[", rest::bits>>, pos, path), do: array(rest, pos + 1, path)
  defp value(<<q, rest::bits>>, pos, _path) when q in ~c"\"'", do: string(rest, pos + 1, q, [])
  defp value(<<"true", rest::bits>>, pos, _path), do: {true, rest, pos + 4}
  defp value(<<"false", rest::bits>>, pos, _path), do: {false, rest, pos + 5}
  defp value(<<"null", rest::bits>>, pos, _path), do: {nil, rest, pos + 4}

  defp value(<<b, _::bits>> = rest, pos, _path) when b in ~c"+-.0123456789IN",
    do: number(rest, pos)

  defp value(rest, pos, _path), do: unexpected(rest, pos)

  defp object(rest, pos, path) do
    {rest, pos} = ws(rest, pos)

    case rest do
      <<"}", rest::bits>> -> {%{}, rest, pos + 1}
      _ -> members(rest, pos, path, %{})
    end
  end

  defp members(rest, pos, path, acc) do
    key_pos = pos
    {key, rest, pos} = key(rest, pos)

    if is_map_key(acc, key) do
      throw(
        {__MODULE__, :duplicate_key, "duplicate object key #{inspect(key)}", key_pos,
         %{key: key, path: Enum.reverse(path)}}
      )
    end

    {rest, pos} = ws(rest, pos)

    {rest, pos} =
      case rest do
        <<":", rest::bits>> -> ws(rest, pos + 1)
        _ -> unexpected(rest, pos)
      end

    {value, rest, pos} = value(rest, pos, [key | path])
    acc = Map.put(acc, key, value)
    {rest, pos} = ws(rest, pos)

    case rest do
      <<"}", rest::bits>> ->
        {acc, rest, pos + 1}

      <<",", rest::bits>> ->
        {rest, pos} = ws(rest, pos + 1)

        case rest do
          <<"}", rest::bits>> -> {acc, rest, pos + 1}
          _ -> members(rest, pos, path, acc)
        end

      _ ->
        unexpected(rest, pos)
    end
  end

  defp array(rest, pos, path) do
    {rest, pos} = ws(rest, pos)

    case rest do
      <<"]", rest::bits>> -> {[], rest, pos + 1}
      _ -> elements(rest, pos, path, 0, [])
    end
  end

  defp elements(rest, pos, path, index, acc) do
    {value, rest, pos} = value(rest, pos, [index | path])
    acc = [value | acc]
    {rest, pos} = ws(rest, pos)

    case rest do
      <<"]", rest::bits>> ->
        {Enum.reverse(acc), rest, pos + 1}

      <<",", rest::bits>> ->
        {rest, pos} = ws(rest, pos + 1)

        case rest do
          <<"]", rest::bits>> -> {Enum.reverse(acc), rest, pos + 1}
          _ -> elements(rest, pos, path, index + 1, acc)
        end

      _ ->
        unexpected(rest, pos)
    end
  end

  # -- Keys --------------------------------------------------------------------------

  defp key(<<q, rest::bits>>, pos) when q in ~c"\"'", do: string(rest, pos + 1, q, [])

  defp key(rest, pos) do
    case identifier_char(rest, pos) do
      {c, rest2, pos2} ->
        if id_start?(c), do: identifier(rest2, pos2, [<<c::utf8>>]), else: unexpected(rest, pos)

      :none ->
        unexpected(rest, pos)
    end
  end

  defp identifier(rest, pos, acc) do
    case identifier_char(rest, pos) do
      {c, rest2, pos2} ->
        if id_part?(c),
          do: identifier(rest2, pos2, [acc | <<c::utf8>>]),
          else: {IO.iodata_to_binary(acc), rest, pos}

      :none ->
        {IO.iodata_to_binary(acc), rest, pos}
    end
  end

  # Reads one source character of an identifier: a literal character or a
  # `\uXXXX` escape (ES5.1 IdentifierName allows only that escape form).
  defp identifier_char(<<"\\u", a, b, c, d, rest::bits>>, pos) do
    case hex4(a, b, c, d) do
      cp when is_integer(cp) and cp not in 0xD800..0xDFFF -> {cp, rest, pos + 6}
      _ -> fail("invalid identifier escape", pos)
    end
  end

  defp identifier_char(<<"\\", _::bits>>, pos), do: fail("invalid identifier escape", pos)
  defp identifier_char(<<c::utf8, rest::bits>>, pos), do: {c, rest, pos + utf8_size(c)}
  defp identifier_char(_rest, _pos), do: :none

  # ES5.1 IdentifierStart: UnicodeLetter (Lu Ll Lt Lm Lo Nl), "$", "_".
  defp id_start?(c) when c in ?a..?z or c in ?A..?Z or c in [?$, ?_], do: true
  defp id_start?(c) when c < 0x80, do: false
  defp id_start?(c), do: category?(c, "^[\\p{L}\\p{Nl}]$")

  # ES5.1 IdentifierPart: IdentifierStart, UnicodeCombiningMark (Mn Mc),
  # UnicodeDigit (Nd), UnicodeConnectorPunctuation (Pc), ZWNJ, ZWJ.
  defp id_part?(c) when c in ?0..?9, do: true
  defp id_part?(c) when c in [0x200C, 0x200D], do: true
  defp id_part?(c) when c < 0x80, do: id_start?(c)
  defp id_part?(c), do: category?(c, "^[\\p{L}\\p{Nl}\\p{Mn}\\p{Mc}\\p{Nd}\\p{Pc}]$")

  # General-category test on a single code point using PCRE's Unicode tables.
  defp category?(c, pattern), do: :re.run(<<c::utf8>>, pattern, [:unicode, :ucp]) != :nomatch

  # -- Strings -----------------------------------------------------------------------

  defp string(<<q, rest::bits>>, pos, q, acc), do: {binary(acc, pos), rest, pos + 1}

  defp string(<<"\\", rest::bits>>, pos, q, acc), do: escape(rest, pos, q, acc)

  defp string(<<b, _::bits>>, pos, _q, _acc) when b in ~c"\n\r",
    do: fail("unescaped line terminator in string", pos)

  defp string(<<b, rest::bits>>, pos, q, acc) when b < 0x80,
    do: string(rest, pos + 1, q, [acc, b])

  defp string(<<c::utf8, rest::bits>>, pos, q, acc),
    do: string(rest, pos + utf8_size(c), q, [acc | <<c::utf8>>])

  defp string(<<>>, pos, _q, _acc), do: fail("unterminated string", pos)
  defp string(_rest, pos, _q, _acc), do: fail("invalid UTF-8", pos)

  @single_escapes %{
    ?' => ?',
    ?" => ?",
    ?\\ => ?\\,
    ?b => ?\b,
    ?f => ?\f,
    ?n => ?\n,
    ?r => ?\r,
    ?t => ?\t,
    ?v => ?\v
  }

  # `pos` is the offset of the backslash.
  defp escape(<<c, rest::bits>>, pos, q, acc) when is_map_key(@single_escapes, c),
    do: string(rest, pos + 2, q, [acc, Map.fetch!(@single_escapes, c)])

  defp escape(<<?0, d, _::bits>>, pos, _q, _acc) when d in ?0..?9,
    do: fail("octal escapes are not allowed", pos)

  defp escape(<<?0, rest::bits>>, pos, q, acc), do: string(rest, pos + 2, q, [acc, 0])
  defp escape(<<d, _::bits>>, pos, _q, _acc) when d in ?1..?9, do: fail("invalid escape", pos)

  defp escape(<<?x, a, b, rest::bits>>, pos, q, acc) do
    with x when is_integer(x) <- hex(a), y when is_integer(y) <- hex(b) do
      string(rest, pos + 4, q, [acc | <<x * 16 + y::utf8>>])
    else
      _ -> fail("invalid \\x escape", pos)
    end
  end

  defp escape(<<?x, _::bits>>, pos, _q, _acc), do: fail("invalid \\x escape", pos)

  defp escape(<<?u, a, b, c, d, rest::bits>>, pos, q, acc) do
    case hex4(a, b, c, d) do
      hi when hi in 0xD800..0xDBFF ->
        case rest do
          <<"\\u", e, f, g, h, rest::bits>> ->
            case hex4(e, f, g, h) do
              lo when lo in 0xDC00..0xDFFF ->
                cp = 0x10000 + ((hi - 0xD800) <<< 10) + (lo - 0xDC00)
                string(rest, pos + 12, q, [acc | <<cp::utf8>>])

              _ ->
                lone_surrogate(pos)
            end

          _ ->
            lone_surrogate(pos)
        end

      cp when cp in 0xDC00..0xDFFF ->
        lone_surrogate(pos)

      cp when is_integer(cp) ->
        string(rest, pos + 6, q, [acc | <<cp::utf8>>])

      :error ->
        fail("invalid \\u escape", pos)
    end
  end

  defp escape(<<?u, _::bits>>, pos, _q, _acc), do: fail("invalid \\u escape", pos)

  # LineContinuation: a backslash followed by a LineTerminatorSequence.
  defp escape(<<"\r\n", rest::bits>>, pos, q, acc), do: string(rest, pos + 3, q, acc)

  defp escape(<<b, rest::bits>>, pos, q, acc) when b in ~c"\n\r",
    do: string(rest, pos + 2, q, acc)

  defp escape(<<c::utf8, rest::bits>>, pos, q, acc) when c in [0x2028, 0x2029],
    do: string(rest, pos + 4, q, acc)

  # NonEscapeCharacter: the character itself.
  defp escape(<<c::utf8, rest::bits>>, pos, q, acc),
    do: string(rest, pos + 1 + utf8_size(c), q, [acc | <<c::utf8>>])

  defp escape(<<>>, pos, _q, _acc), do: fail("unterminated string", pos + 1)
  defp escape(_rest, pos, _q, _acc), do: fail("invalid UTF-8", pos + 1)

  defp lone_surrogate(pos),
    do: fail("unpaired surrogate escape cannot be represented as UTF-8 text", pos)

  defp binary(acc, _pos), do: IO.iodata_to_binary(acc)

  # -- Numbers -----------------------------------------------------------------------

  defp number(rest, pos) do
    {sign, body, body_pos} =
      case rest do
        <<"+", body::bits>> -> {"+", body, pos + 1}
        <<"-", body::bits>> -> {"-", body, pos + 1}
        _ -> {"", rest, pos}
      end

    case body do
      <<"Infinity", rest::bits>> ->
        {if(sign == "-", do: :negative_infinity, else: :infinity), rest, body_pos + 8}

      <<"NaN", rest::bits>> ->
        {:nan, rest, body_pos + 3}

      <<"0", x, h, _::bits>> when x in ~c"xX" ->
        if hex(h) == :error, do: fail("invalid hexadecimal number", body_pos + 2)

        {digits, rest} =
          take_while(binary_part(body, 2, byte_size(body) - 2), &(hex(&1) != :error))

        int = check_digits(digits, pos) |> String.to_integer(16)
        {if(sign == "-", do: -int, else: int), rest, body_pos + 2 + byte_size(digits)}

      <<"0", x, _::bits>> when x in ~c"xX" ->
        fail("invalid hexadecimal number", body_pos + 2)

      _ ->
        decimal(sign, body, pos, body_pos)
    end
  end

  defp decimal(sign, body, pos, body_pos) do
    {int, rest} = take_while(body, &(&1 in ?0..?9))

    if byte_size(int) > 1 and binary_part(int, 0, 1) == "0",
      do: fail("leading zeros are not allowed", body_pos)

    {frac, rest} =
      case rest do
        <<".", rest::bits>> ->
          {frac, rest} = take_while(rest, &(&1 in ?0..?9))
          {{frac}, rest}

        _ ->
          {nil, rest}
      end

    if int == "" and (frac == nil or frac == {""}), do: unexpected(body, body_pos)

    {exp, rest} =
      case rest do
        <<e, rest::bits>> when e in ~c"eE" ->
          {exp_sign, rest} =
            case rest do
              <<s, rest::bits>> when s in ~c"+-" -> {<<s>>, rest}
              _ -> {"", rest}
            end

          case take_while(rest, &(&1 in ?0..?9)) do
            {"", _} ->
              fail("invalid exponent", body_pos + byte_size(body) - byte_size(rest))

            {digits, rest} ->
              {exp_sign <> digits, rest}
          end

        _ ->
          {nil, rest}
      end

    end_pos = body_pos + byte_size(body) - byte_size(rest)

    value =
      case {frac, exp} do
        {nil, nil} ->
          int = check_digits(sign <> int, pos) |> String.to_integer()
          int

        _ ->
          f = fraction_digits(frac)
          i = if int == "", do: "0", else: int
          text = sign <> i <> "." <> f <> "e" <> (exp || "0")

          try do
            :erlang.binary_to_float(text)
          rescue
            ArgumentError -> fail("number is outside the finite float range", pos)
          end
      end

    {value, rest, end_pos}
  end

  defp fraction_digits({digits}) when digits != "", do: digits
  defp fraction_digits(_), do: "0"

  defp check_digits(text, pos) do
    if byte_size(text) > @integer_digit_limit,
      do: fail("integer exceeds #{@integer_digit_limit} digits", pos),
      else: text
  end

  defp take_while(bin, pred), do: take_while(bin, pred, 0)

  defp take_while(bin, pred, n) do
    if n < byte_size(bin) and pred.(:binary.at(bin, n)),
      do: take_while(bin, pred, n + 1),
      else: {binary_part(bin, 0, n), binary_part(bin, n, byte_size(bin) - n)}
  end

  # -- Helpers -----------------------------------------------------------------------

  defp hex4(a, b, c, d) do
    with x when is_integer(x) <- hex(a),
         y when is_integer(y) <- hex(b),
         z when is_integer(z) <- hex(c),
         w when is_integer(w) <- hex(d) do
      x * 4096 + y * 256 + z * 16 + w
    end
  end

  defp hex(c) when c in ?0..?9, do: c - ?0
  defp hex(c) when c in ?a..?f, do: c - ?a + 10
  defp hex(c) when c in ?A..?F, do: c - ?A + 10
  defp hex(_), do: :error

  defp utf8_size(c) when c < 0x80, do: 1
  defp utf8_size(c) when c < 0x800, do: 2
  defp utf8_size(c) when c < 0x10000, do: 3
  defp utf8_size(_), do: 4

  defp unexpected(<<>>, pos), do: fail("unexpected end of input", pos)

  defp unexpected(<<c::utf8, _::bits>>, pos),
    do: fail("unexpected character #{inspect(<<c::utf8>>)}", pos)

  defp unexpected(_rest, pos), do: fail("invalid UTF-8", pos)

  defp fail(message, pos), do: throw({__MODULE__, :syntax, message, pos, %{}})
end
