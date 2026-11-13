defmodule Formata.Codec.JSON.Stream.Machine do
  @moduledoc false
  # The incremental JSON state machine behind `Formata.Codec.JSON.Stream`.
  #
  # `run/2` scans `data` (the carried bytes of the previous chunk followed by
  # the new chunk) exactly once. It returns how many bytes were consumed; the
  # unconsumed tail is at most a few bytes of an indivisible unit (a partial
  # UTF-8 character, `\uXXXX` escape or surrogate pair, literal, `/`, or the
  # `*` of a block comment end) and is carried into the next call.
  #
  # Tokens that span chunks (strings, numbers, comments) keep their progress in
  # `state.token`. String and number pieces taken from `data` are collected in
  # the token's `fresh` iodata; `Formata.Codec.JSON.Stream` copies them at the
  # end of each feed so no reference to the chunk binary is retained.
  #
  # Failures are thrown as `{__MODULE__, code, message, index, state}` and
  # turned into `Formata.Error` values by `run/2`'s caller.

  # Grammar modes:
  #   {:value, close}  expecting a value; close is nil | :empty | :trailing
  #   {:key, close}    expecting an object key; close as above
  #   :colon           expecting ":"
  #   :after           a value inside a container is complete
  #   :done            the root value is complete
  #
  # Stack frames (innermost first):
  #   {:array, index}
  #   {:object, seen_keys :: map, current_key :: binary | nil}
  #
  # Tokens:
  #   nil
  #   {:string, :key | :value, acc :: iodata, fresh :: iodata, size}
  #   {:number, nstate, acc :: iodata, fresh :: iodata, size}
  #   :line_comment
  #   :block_comment

  import Bitwise, only: [<<<: 2]

  @integer_digit_limit 1024

  @doc false
  def run(data, st) do
    {consumed, st, events} = resume(data, 0, data, st, [])
    {:ok, consumed, st, events}
  catch
    {__MODULE__, code, message, index, st} -> {:error, code, message, index, st}
  end

  @doc false
  # Completes a pending number at the end of input. Other tokens are left for
  # the caller to report as incomplete.
  def finish_number(%{token: {:number, nstate, acc, fresh, _size}} = st)
      when nstate in [:zero, :int, :frac, :exp_digits] do
    value = number_value(IO.iodata_to_binary([acc | fresh]), 0, st)
    {st, events} = emit_value(value, %{st | token: nil}, [])
    {:ok, st, events}
  catch
    {__MODULE__, code, message, index, st} -> {:error, code, message, index, st}
  end

  def finish_number(st), do: {:ok, st, []}

  @doc false
  def path(stack), do: path(stack, [])

  defp path([], acc), do: acc
  defp path([{:array, index} | rest], acc), do: path(rest, [index | acc])
  defp path([{:object, _seen, nil} | rest], acc), do: path(rest, acc)
  defp path([{:object, _seen, key} | rest], acc), do: path(rest, [key | acc])

  # -- Dispatch -----------------------------------------------------------------

  defp resume(rest, i, data, %{token: nil} = st, ev), do: dispatch(rest, i, data, st, ev)

  defp resume(rest, i, data, %{token: {:string, _, _, _, _}} = st, ev),
    do: string(rest, i, i, data, st, ev)

  defp resume(rest, i, data, %{token: {:number, nstate, _, _, _}} = st, ev),
    do: number(rest, i, i, nstate, data, st, ev)

  defp resume(rest, i, data, %{token: :line_comment} = st, ev),
    do: line_comment(rest, i, data, st, ev)

  defp resume(rest, i, data, %{token: :block_comment} = st, ev),
    do: block_comment(rest, i, data, st, ev)

  defp dispatch(<<b, rest::bits>>, i, data, st, ev) when b in ~c"\s\t\n\r",
    do: dispatch(rest, i + 1, data, st, ev)

  defp dispatch(<<?/, rest::bits>>, i, data, st, ev) do
    cond do
      not st.comments -> fail(:syntax, :byte, i, st)
      rest == <<>> -> {i, st, ev}
      true -> comment_start(rest, i, data, st, ev)
    end
  end

  defp dispatch(<<>>, i, _data, st, ev), do: {i, st, ev}

  defp dispatch(<<b, rest::bits>> = all, i, data, st, ev),
    do: token(st.mode, b, rest, all, i, data, st, ev)

  defp comment_start(<<?/, rest::bits>>, i, data, st, ev),
    do: line_comment(rest, i + 2, data, %{st | token: :line_comment}, ev)

  defp comment_start(<<?*, rest::bits>>, i, data, st, ev),
    do: block_comment(rest, i + 2, data, %{st | token: :block_comment}, ev)

  defp comment_start(_rest, i, _data, st, _ev), do: fail(:syntax, :byte, i + 1, st)

  # -- Grammar ------------------------------------------------------------------

  defp token({:value, _close}, ?{, rest, _all, i, data, st, ev),
    do: open(:object, rest, i, data, st, ev)

  defp token({:value, _close}, ?[, rest, _all, i, data, st, ev),
    do: open(:array, rest, i, data, st, ev)

  defp token({:value, close}, ?], rest, _all, i, data, st, ev)
       when close == :empty or (close == :trailing and st.trailing_commas),
       do: close(rest, i, data, st, ev)

  defp token({:value, _close}, ?", rest, _all, i, data, st, ev),
    do: string(rest, i + 1, i + 1, data, %{st | token: {:string, :value, [], [], 0}}, ev)

  defp token({:value, _close}, ?-, rest, _all, i, data, st, ev),
    do: number(rest, i + 1, i, :minus, data, %{st | token: {:number, :minus, [], [], 0}}, ev)

  defp token({:value, _close}, ?0, rest, _all, i, data, st, ev),
    do: number(rest, i + 1, i, :zero, data, %{st | token: {:number, :zero, [], [], 0}}, ev)

  defp token({:value, _close}, b, rest, _all, i, data, st, ev) when b in ?1..?9,
    do: number(rest, i + 1, i, :int, data, %{st | token: {:number, :int, [], [], 0}}, ev)

  defp token({:value, _close}, ?t, _rest, all, i, data, st, ev),
    do: literal("true", true, all, i, data, st, ev)

  defp token({:value, _close}, ?f, _rest, all, i, data, st, ev),
    do: literal("false", false, all, i, data, st, ev)

  defp token({:value, _close}, ?n, _rest, all, i, data, st, ev),
    do: literal("null", nil, all, i, data, st, ev)

  defp token({:key, _close}, ?", rest, _all, i, data, st, ev),
    do: string(rest, i + 1, i + 1, data, %{st | token: {:string, :key, [], [], 0}}, ev)

  defp token({:key, close}, ?}, rest, _all, i, data, st, ev)
       when close == :empty or (close == :trailing and st.trailing_commas),
       do: close(rest, i, data, st, ev)

  defp token(:colon, ?:, rest, _all, i, data, st, ev),
    do: dispatch(rest, i + 1, data, %{st | mode: {:value, nil}}, ev)

  defp token(:after, ?,, rest, _all, i, data, st, ev) do
    st =
      case st.stack do
        [{:array, index} | stack] ->
          %{st | stack: [{:array, index + 1} | stack], mode: {:value, :trailing}}

        [{:object, _, _} | _] ->
          %{st | mode: {:key, :trailing}}
      end

    dispatch(rest, i + 1, data, st, ev)
  end

  defp token(:after, ?], rest, _all, i, data, %{stack: [{:array, _} | _]} = st, ev),
    do: close(rest, i, data, st, ev)

  defp token(:after, ?}, rest, _all, i, data, %{stack: [{:object, _, _} | _]} = st, ev),
    do: close(rest, i, data, st, ev)

  defp token(_mode, _b, _rest, _all, i, _data, st, _ev), do: fail(:syntax, :byte, i, st)

  defp open(kind, rest, i, data, st, ev) do
    if st.depth >= st.max_depth do
      fail(:limit_exceeded, "maximum nesting depth of #{st.max_depth} exceeded", i, st)
    end

    {event, frame, mode} =
      case kind do
        :object -> {:start_object, {:object, %{}, nil}, {:key, :empty}}
        :array -> {:start_array, {:array, 0}, {:value, :empty}}
      end

    ev = [{event, path(st.stack)} | ev]
    st = %{st | stack: [frame | st.stack], depth: st.depth + 1, mode: mode}
    dispatch(rest, i + 1, data, st, ev)
  end

  defp close(rest, i, data, %{stack: [frame | stack]} = st, ev) do
    event = if elem(frame, 0) == :array, do: :end_array, else: :end_object
    ev = [{event, path(stack)} | ev]
    st = value_done(%{st | stack: stack, depth: st.depth - 1})
    dispatch(rest, i + 1, data, st, ev)
  end

  defp value_done(%{stack: []} = st), do: %{st | mode: :done}
  defp value_done(st), do: %{st | mode: :after}

  defp emit_value(value, st, ev),
    do: {value_done(st), [{:value, path(st.stack), value} | ev]}

  defp literal(word, value, all, i, data, st, ev) do
    size = byte_size(word)
    available = byte_size(all)

    cond do
      available >= size and binary_part(all, 0, size) == word ->
        {st, ev} = emit_value(value, st, ev)
        rest = binary_part(all, size, available - size)
        dispatch(rest, i + size, data, st, ev)

      available < size and binary_part(word, 0, available) == all ->
        # A valid prefix such as "tru": wait for more input.
        {i, st, ev}

      true ->
        fail(:syntax, :byte, i, st)
    end
  end

  # -- Comments -----------------------------------------------------------------

  defp line_comment(<<b, _::bits>> = rest, i, data, st, ev) when b in ~c"\n\r",
    do: dispatch(rest, i, data, %{st | token: nil}, ev)

  defp line_comment(<<b, rest::bits>>, i, data, st, ev) when b < 0x80,
    do: line_comment(rest, i + 1, data, st, ev)

  defp line_comment(<<c::utf8, rest::bits>>, i, data, st, ev),
    do: line_comment(rest, i + utf8_size(c), data, st, ev)

  defp line_comment(<<>>, i, _data, st, ev), do: {i, st, ev}
  defp line_comment(rest, i, _data, st, ev), do: utf8_tail(rest, i, st, ev)

  defp block_comment(<<?*, ?/, rest::bits>>, i, data, st, ev),
    do: dispatch(rest, i + 2, data, %{st | token: nil}, ev)

  defp block_comment(<<?*>>, i, _data, st, ev), do: {i, st, ev}

  defp block_comment(<<b, rest::bits>>, i, data, st, ev) when b < 0x80,
    do: block_comment(rest, i + 1, data, st, ev)

  defp block_comment(<<c::utf8, rest::bits>>, i, data, st, ev),
    do: block_comment(rest, i + utf8_size(c), data, st, ev)

  defp block_comment(<<>>, i, _data, st, ev), do: {i, st, ev}
  defp block_comment(rest, i, _data, st, ev), do: utf8_tail(rest, i, st, ev)

  # -- Strings ------------------------------------------------------------------

  # `start` is the index in `data` where the current run of literal bytes began.
  defp string(<<?", rest::bits>>, i, start, data, st, ev) do
    st = take_run(st, data, start, i)
    {:string, role, acc, fresh, _size} = st.token
    value = binary([acc | fresh])
    st = %{st | token: nil}

    case role do
      :value ->
        ev =
          if st.string_deltas and fresh != [] do
            [{:string_delta, path(st.stack), binary(fresh)} | ev]
          else
            ev
          end

        {st, ev} = emit_value(value, st, ev)
        dispatch(rest, i + 1, data, st, ev)

      :key ->
        {st, ev} = key(value, i, st, ev)
        dispatch(rest, i + 1, data, st, ev)
    end
  end

  defp string(<<?\\, rest::bits>>, i, start, data, st, ev) do
    st = take_run(st, data, start, i)
    escape(rest, i, data, st, ev)
  end

  defp string(<<b, _::bits>>, i, _start, _data, st, _ev) when b < 0x20,
    do: fail(:syntax, :byte, i, st)

  defp string(<<b, rest::bits>>, i, start, data, st, ev) when b < 0x80,
    do: string(rest, i + 1, start, data, st, ev)

  defp string(<<c::utf8, rest::bits>>, i, start, data, st, ev),
    do: string(rest, i + utf8_size(c), start, data, st, ev)

  defp string(<<>>, i, start, data, st, ev), do: {i, take_run(st, data, start, i), ev}

  defp string(rest, i, start, data, st, ev),
    do: utf8_tail(rest, i, take_run(st, data, start, i), ev)

  @simple_escapes %{
    ?" => ?",
    ?\\ => ?\\,
    ?/ => ?/,
    ?b => ?\b,
    ?f => ?\f,
    ?n => ?\n,
    ?r => ?\r,
    ?t => ?\t
  }

  # `i` is the index of the backslash.
  defp escape(<<c, rest::bits>>, i, data, st, ev) when is_map_key(@simple_escapes, c) do
    st = append(st, Map.fetch!(@simple_escapes, c), 1, i)
    string(rest, i + 2, i + 2, data, st, ev)
  end

  defp escape(<<?u, a, b, c, d, rest::bits>>, i, data, st, ev) do
    case hex4(a, b, c, d) do
      cp when cp in 0xD800..0xDBFF ->
        surrogate(rest, cp, i, data, st, ev)

      cp when cp in 0xDC00..0xDFFF ->
        fail(:syntax, "lone low surrogate escape", i, st)

      cp when is_integer(cp) ->
        st = append(st, <<cp::utf8>>, utf8_size(cp), i)
        string(rest, i + 6, i + 6, data, st, ev)

      :error ->
        fail(:syntax, "invalid \\u escape", i, st)
    end
  end

  defp escape(<<?u, partial::bits>>, i, _data, st, ev) do
    if all_hex?(partial), do: {i, st, ev}, else: fail(:syntax, "invalid \\u escape", i, st)
  end

  defp escape(<<>>, i, _data, st, ev), do: {i, st, ev}
  defp escape(_rest, i, _data, st, _ev), do: fail(:syntax, :byte, i + 1, st)

  # `rest` follows a high-surrogate escape; a low-surrogate escape must follow.
  defp surrogate(<<?\\, ?u, a, b, c, d, rest::bits>>, hi, i, data, st, ev) do
    case hex4(a, b, c, d) do
      lo when lo in 0xDC00..0xDFFF ->
        cp = 0x10000 + ((hi - 0xD800) <<< 10) + (lo - 0xDC00)
        st = append(st, <<cp::utf8>>, 4, i)
        string(rest, i + 12, i + 12, data, st, ev)

      _ ->
        fail(:syntax, "high surrogate escape not followed by a low surrogate escape", i, st)
    end
  end

  defp surrogate(rest, _hi, i, _data, st, ev) do
    if low_surrogate_prefix?(rest),
      do: {i, st, ev},
      else: fail(:syntax, "high surrogate escape not followed by a low surrogate escape", i, st)
  end

  defp low_surrogate_prefix?(<<>>), do: true
  defp low_surrogate_prefix?(<<?\\>>), do: true
  defp low_surrogate_prefix?(<<?\\, ?u>>), do: true
  defp low_surrogate_prefix?(<<?\\, ?u, d>>) when d in ~c"dD", do: true

  defp low_surrogate_prefix?(<<?\\, ?u, d, c, rest::bits>>)
       when d in ~c"dD" and c in ~c"cdefCDEF",
       do: all_hex?(rest)

  defp low_surrogate_prefix?(_), do: false

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

  defp all_hex?(bin), do: for(<<c <- bin>>, reduce: true, do: (acc -> acc and hex(c) != :error))

  # Appends the literal run data[start, i) to the string token.
  defp take_run(st, _data, start, start), do: st

  defp take_run(st, data, start, i),
    do: append(st, binary_part(data, start, i - start), i - start, i)

  defp append(%{token: {:string, role, acc, fresh, size}} = st, piece, piece_size, i) do
    size = size + piece_size

    if size > st.max_token_bytes do
      fail(:limit_exceeded, "string exceeds max_token_bytes (#{st.max_token_bytes})", i, st)
    end

    %{st | token: {:string, role, acc, [fresh | [piece]], size}}
  end

  defp key(key, i, %{stack: [{:object, seen, _} | stack]} = st, ev) do
    if is_map_key(seen, key) do
      fail(:duplicate_key, {:duplicate_key, key, path(stack)}, i, st)
    end

    stack = [{:object, Map.put(seen, key, true), key} | stack]
    {%{st | stack: stack, mode: :colon}, [{:key, path(stack), key} | ev]}
  end

  # Returns a binary that does not reference a larger binary (the chunk).
  defp binary(iodata) do
    bin = IO.iodata_to_binary(iodata)
    if :binary.referenced_byte_size(bin) > byte_size(bin), do: :binary.copy(bin), else: bin
  end

  # -- Numbers ------------------------------------------------------------------

  defp number(<<b, rest::bits>>, i, start, nstate, data, st, ev) do
    case number_step(nstate, b) do
      :error ->
        fail(:syntax, :byte, i, st)

      :end ->
        number_end(<<b, rest::bits>>, i, start, nstate, data, st, ev)

      next ->
        number(rest, i + 1, start, next, data, st, ev)
    end
  end

  defp number(<<>>, i, start, nstate, data, st, ev) do
    {:number, _, acc, fresh, size} = st.token
    size = size + i - start

    if size > st.max_token_bytes do
      fail(:limit_exceeded, "number exceeds max_token_bytes (#{st.max_token_bytes})", i, st)
    end

    fresh = if i > start, do: [fresh | [binary_part(data, start, i - start)]], else: fresh
    {i, %{st | token: {:number, nstate, acc, fresh, size}}, ev}
  end

  defp number_end(rest, i, start, _nstate, data, st, ev) do
    {:number, _, acc, fresh, _size} = st.token
    text = IO.iodata_to_binary([acc, fresh, binary_part(data, start, i - start)])
    value = number_value(text, i, st)
    {st, ev} = emit_value(value, %{st | token: nil}, ev)
    dispatch(rest, i, data, st, ev)
  end

  # :zero, :int, :frac and :exp_digits are complete numbers; the others need
  # more digits.
  defp number_step(:minus, ?0), do: :zero
  defp number_step(:minus, b) when b in ?1..?9, do: :int
  defp number_step(:minus, _), do: :error
  defp number_step(:zero, ?.), do: :dot
  defp number_step(:zero, b) when b in ~c"eE", do: :exp
  defp number_step(:zero, _), do: :end
  defp number_step(:int, b) when b in ?0..?9, do: :int
  defp number_step(:int, ?.), do: :dot
  defp number_step(:int, b) when b in ~c"eE", do: :exp
  defp number_step(:int, _), do: :end
  defp number_step(:dot, b) when b in ?0..?9, do: :frac
  defp number_step(:dot, _), do: :error
  defp number_step(:frac, b) when b in ?0..?9, do: :frac
  defp number_step(:frac, b) when b in ~c"eE", do: :exp
  defp number_step(:frac, _), do: :end
  defp number_step(:exp, b) when b in ?0..?9, do: :exp_digits
  defp number_step(:exp, b) when b in ~c"+-", do: :exp_sign
  defp number_step(:exp, _), do: :error
  defp number_step(:exp_sign, b) when b in ?0..?9, do: :exp_digits
  defp number_step(:exp_sign, _), do: :error
  defp number_step(:exp_digits, b) when b in ?0..?9, do: :exp_digits
  defp number_step(:exp_digits, _), do: :end

  # Same conversions and limits as the Formata.Jason decoder.
  defp number_value(text, i, st) do
    case :binary.split(text, ["e", "E"]) do
      [mantissa] ->
        if String.contains?(mantissa, ".") do
          to_float(text, text, i, st)
        else
          if byte_size(text) > @integer_digit_limit do
            fail(:syntax, "integer exceeds #{@integer_digit_limit} bytes", i, st)
          end

          String.to_integer(text)
        end

      [mantissa, exponent] ->
        mantissa = if String.contains?(mantissa, "."), do: mantissa, else: mantissa <> ".0"
        to_float(mantissa <> "e" <> exponent, text, i, st)
    end
  end

  defp to_float(string, text, i, st) do
    :erlang.binary_to_float(string)
  rescue
    ArgumentError -> fail(:syntax, "number #{text} is outside the float range", i, st)
  end

  # -- UTF-8 --------------------------------------------------------------------

  defp utf8_size(c) when c < 0x80, do: 1
  defp utf8_size(c) when c < 0x800, do: 2
  defp utf8_size(c) when c < 0x10000, do: 3
  defp utf8_size(_), do: 4

  # `rest` did not start with a complete valid UTF-8 character. If it is a
  # valid prefix cut by the end of the chunk, wait for more input.
  defp utf8_tail(rest, i, st, ev) do
    if byte_size(rest) < 4 and utf8_prefix?(rest),
      do: {i, st, ev},
      else: fail(:syntax, "invalid UTF-8", i, st)
  end

  defp utf8_prefix?(<<a>>), do: utf8_length(a) > 1
  defp utf8_prefix?(<<a, b>>), do: utf8_length(a) > 2 and second_byte?(a, b)

  defp utf8_prefix?(<<a, b, c>>),
    do: utf8_length(a) > 3 and second_byte?(a, b) and c in 0x80..0xBF

  defp utf8_length(a) when a in 0xC2..0xDF, do: 2
  defp utf8_length(a) when a in 0xE0..0xEF, do: 3
  defp utf8_length(a) when a in 0xF0..0xF4, do: 4
  defp utf8_length(_), do: 0

  defp second_byte?(0xE0, b), do: b in 0xA0..0xBF
  defp second_byte?(0xED, b), do: b in 0x80..0x9F
  defp second_byte?(0xF0, b), do: b in 0x90..0xBF
  defp second_byte?(0xF4, b), do: b in 0x80..0x8F
  defp second_byte?(_, b), do: b in 0x80..0xBF

  defp fail(code, message, index, st), do: throw({__MODULE__, code, message, index, st})
end
