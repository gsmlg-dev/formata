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
  # the token. String and number pieces taken from `data` are collected in the
  # token's `fresh` iodata; `Formata.Codec.JSON.Stream` copies them at the end
  # of each feed so no reference to the chunk binary is retained.
  #
  # Performance notes (see bench/json_stream.exs):
  #
  #   * The state that changes per token lives in a small record (`m`), stored
  #     in the parser struct's `m` field: updating a 4-field record allocates
  #     far less than copying the struct with its options and position fields.
  #     The struct `c` is passed along read-only as configuration, and
  #     `Formata.Codec.JSON.Stream` updates it once per feed.
  #   * The remaining input is always the first argument of a function that
  #     starts with a binary match, so the compiler reuses the match context
  #     instead of allocating a sub-binary per token
  #     (`ERL_COMPILER_OPTIONS=bin_opt_info mix compile --force` shows this).
  #   * Containers cache their own path, and a member's key path is shared by
  #     its :key and :value events.
  #
  # Failures are thrown as `{__MODULE__, code, message, index, state}` and
  # returned by `run/2` as `{:error, code, message, index, %{stack: stack}}`.

  # Grammar modes:
  #   {:value, close}  expecting a value; close is nil | :empty | :trailing
  #   {:key, close}    expecting an object key; close as above
  #   :colon           expecting ":"
  #   :after           a value inside a container is complete
  #   :done            the root value is complete
  #
  # Stack frames (innermost first). Each frame caches the container's own path:
  #   {:array, index, path}
  #   {:object, seen_keys :: map, key_path :: [term] | nil, path}
  # `key_path` is `path ++ [current_key]`.
  #
  # Tokens:
  #   nil
  #   {:string, :key | :value, acc :: iodata, fresh :: iodata, size}
  #   {:number, nstate, acc :: iodata, fresh :: iodata, size}
  #   :line_comment
  #   :block_comment

  import Bitwise, only: [<<<: 2]
  import Record, only: [defrecordp: 2]

  defrecordp :m, mode: {:value, nil}, stack: [], depth: 0, token: nil

  @integer_digit_limit 1024

  @doc false
  def initial, do: m()

  @doc false
  def mode(m(mode: mode)), do: mode
  @doc false
  def stack(m(stack: stack)), do: stack
  @doc false
  def token(m(token: token)), do: token

  @doc false
  # `c` is the `Formata.Codec.JSON.Stream` struct (read-only configuration and
  # the machine state in `c.m`). Returns the consumed byte count, the new
  # machine state, and the events in reverse order.
  def run(data, c) do
    {consumed, st, events} = resume(data, 0, data, c, c.m, [])
    {:ok, consumed, st, events}
  catch
    {__MODULE__, code, message, index, st} ->
      {:error, code, message, index, %{stack: m(st, :stack)}}
  end

  @doc false
  # At the end of a feed: copies the chunk pieces held by an unfinished string
  # or number (so the state does not reference the chunk) and, for string
  # values with `string_deltas`, emits them as a delta.
  def settle(m(token: {:string, role, acc, fresh, size}) = st, deltas?, events)
      when fresh != [] do
    piece = binary(fresh)

    events =
      if role == :value and deltas? and piece != "" do
        [{:string_delta, path(m(st, :stack)), piece} | events]
      else
        events
      end

    {m(st, token: {:string, role, [acc | piece], [], size}), events}
  end

  def settle(m(token: {:number, nstate, acc, fresh, size}) = st, _deltas?, events)
      when fresh != [] do
    {m(st, token: {:number, nstate, [acc | binary(fresh)], [], size}), events}
  end

  def settle(st, _deltas?, events), do: {st, events}

  @doc false
  # Completes a pending number at the end of input. Other tokens are left for
  # the caller to report as incomplete.
  def finish_number(m(token: {:number, nstate, acc, fresh, _size}) = st)
      when nstate in [:zero, :int, :frac, :exp_digits] do
    value = number_value(IO.iodata_to_binary([acc | fresh]), 0, st)
    {st, events} = emit_value(value, st, [])
    {:ok, st, events}
  catch
    {__MODULE__, code, message, index, st} ->
      {:error, code, message, index, %{stack: m(st, :stack)}}
  end

  def finish_number(st), do: {:ok, st, []}

  @doc false
  # The path of the value currently being parsed (or of the innermost
  # container when no member is current).
  def path([]), do: []
  def path([{:array, index, path} | _]), do: path ++ [index]
  def path([{:object, _seen, nil, path} | _]), do: path
  def path([{:object, _seen, key_path, _path} | _]), do: key_path

  # -- Dispatch -----------------------------------------------------------------

  defp resume(rest, i, data, c, m(token: nil) = st, ev), do: dispatch(rest, i, data, c, st, ev)

  defp resume(rest, i, data, c, m(token: {:string, _, _, _, _}) = st, ev),
    do: resume_string(rest, i, data, c, st, ev)

  defp resume(rest, i, data, c, m(token: {:number, nstate, _, _, _}) = st, ev),
    do: number(rest, i, i, nstate, data, c, st, ev)

  defp resume(rest, i, data, c, m(token: :line_comment) = st, ev),
    do: line_comment(rest, i, data, c, st, ev)

  defp resume(rest, i, data, c, m(token: :block_comment) = st, ev),
    do: block_comment(rest, i, data, c, st, ev)

  # Eight spaces at a time: indentation in pretty-printed documents.
  defp dispatch(<<"        ", rest::bits>>, i, data, c, st, ev),
    do: dispatch(rest, i + 8, data, c, st, ev)

  defp dispatch(<<b, rest::bits>>, i, data, c, st, ev) when b in ~c"\s\t\n\r",
    do: dispatch(rest, i + 1, data, c, st, ev)

  defp dispatch(<<?/, rest::bits>>, i, data, c, st, ev) do
    cond do
      not c.comments -> fail(:syntax, :byte, i, st)
      rest == <<>> -> {i, st, ev}
      true -> comment_start(rest, i, data, c, st, ev)
    end
  end

  defp dispatch(<<>>, i, _data, _c, st, ev), do: {i, st, ev}

  defp dispatch(bin, i, data, c, st, ev) do
    case m(st, :mode) do
      {:value, close} -> in_value(bin, close, i, data, c, st, ev)
      {:key, close} -> in_key(bin, close, i, data, c, st, ev)
      :colon -> in_colon(bin, i, data, c, st, ev)
      :after -> in_after(bin, i, data, c, st, ev)
      :done -> fail(:syntax, :byte, i, st)
    end
  end

  defp comment_start(<<?/, rest::bits>>, i, data, c, st, ev),
    do: line_comment(rest, i + 2, data, c, m(st, token: :line_comment), ev)

  defp comment_start(<<?*, rest::bits>>, i, data, c, st, ev),
    do: block_comment(rest, i + 2, data, c, m(st, token: :block_comment), ev)

  defp comment_start(_rest, i, _data, _c, st, _ev), do: fail(:syntax, :byte, i + 1, st)

  # -- Grammar ------------------------------------------------------------------

  defp in_value(<<?", rest::bits>>, _close, i, data, c, st, ev),
    do: string(rest, i + 1, i + 1, [], 0, data, c, m(st, token: {:string, :value, [], [], 0}), ev)

  defp in_value(<<b, rest::bits>>, _close, i, data, c, st, ev) when b in ?1..?9,
    do: number(rest, i + 1, i, :int, data, c, m(st, token: {:number, :int, [], [], 0}), ev)

  defp in_value(<<?{, rest::bits>>, _close, i, data, c, st, ev),
    do: open(:object, rest, i, data, c, st, ev)

  defp in_value(<<?[, rest::bits>>, _close, i, data, c, st, ev),
    do: open(:array, rest, i, data, c, st, ev)

  defp in_value(<<?-, rest::bits>>, _close, i, data, c, st, ev),
    do: number(rest, i + 1, i, :minus, data, c, m(st, token: {:number, :minus, [], [], 0}), ev)

  defp in_value(<<?0, rest::bits>>, _close, i, data, c, st, ev),
    do: number(rest, i + 1, i, :zero, data, c, m(st, token: {:number, :zero, [], [], 0}), ev)

  defp in_value(<<"true", rest::bits>>, _close, i, data, c, st, ev),
    do: literal(rest, true, 4, i, data, c, st, ev)

  defp in_value(<<"false", rest::bits>>, _close, i, data, c, st, ev),
    do: literal(rest, false, 5, i, data, c, st, ev)

  defp in_value(<<"null", rest::bits>>, _close, i, data, c, st, ev),
    do: literal(rest, nil, 4, i, data, c, st, ev)

  defp in_value(<<?], rest::bits>>, close, i, data, c, st, ev)
       when close == :empty or (close == :trailing and c.trailing_commas),
       do: close(rest, i, data, c, st, ev)

  # A literal cut by the end of the chunk ("tru") waits for more input.
  defp in_value(prefix, _close, i, _data, _c, st, ev)
       when prefix in ["t", "tr", "tru", "f", "fa", "fal", "fals", "n", "nu", "nul"],
       do: {i, st, ev}

  defp in_value(_bin, _close, i, _data, _c, st, _ev), do: fail(:syntax, :byte, i, st)

  defp in_key(<<?", rest::bits>>, _close, i, data, c, st, ev),
    do: string(rest, i + 1, i + 1, [], 0, data, c, m(st, token: {:string, :key, [], [], 0}), ev)

  defp in_key(<<?}, rest::bits>>, close, i, data, c, st, ev)
       when close == :empty or (close == :trailing and c.trailing_commas),
       do: close(rest, i, data, c, st, ev)

  defp in_key(_bin, _close, i, _data, _c, st, _ev), do: fail(:syntax, :byte, i, st)

  defp in_colon(<<?:, rest::bits>>, i, data, c, st, ev),
    do: dispatch(rest, i + 1, data, c, m(st, mode: {:value, nil}), ev)

  defp in_colon(_bin, i, _data, _c, st, _ev), do: fail(:syntax, :byte, i, st)

  defp in_after(<<?,, rest::bits>>, i, data, c, st, ev) do
    st =
      case m(st, :stack) do
        [{:array, index, path} | stack] ->
          m(st, stack: [{:array, index + 1, path} | stack], mode: {:value, :trailing})

        [{:object, _, _, _} | _] ->
          m(st, mode: {:key, :trailing})
      end

    dispatch(rest, i + 1, data, c, st, ev)
  end

  defp in_after(<<?], rest::bits>>, i, data, c, m(stack: [{:array, _, _} | _]) = st, ev),
    do: close(rest, i, data, c, st, ev)

  defp in_after(<<?}, rest::bits>>, i, data, c, m(stack: [{:object, _, _, _} | _]) = st, ev),
    do: close(rest, i, data, c, st, ev)

  defp in_after(_bin, i, _data, _c, st, _ev), do: fail(:syntax, :byte, i, st)

  defp open(kind, rest, i, data, c, m(stack: stack, depth: depth) = st, ev) do
    if depth >= c.max_depth do
      fail(:limit_exceeded, "maximum nesting depth of #{c.max_depth} exceeded", i, st)
    end

    path = path(stack)

    {event, frame, mode} =
      case kind do
        :object -> {:start_object, {:object, %{}, nil, path}, {:key, :empty}}
        :array -> {:start_array, {:array, 0, path}, {:value, :empty}}
      end

    st = m(st, stack: [frame | stack], depth: depth + 1, mode: mode)
    dispatch(rest, i + 1, data, c, st, [{event, path} | ev])
  end

  defp close(rest, i, data, c, m(stack: [frame | stack], depth: depth) = st, ev) do
    ev =
      case frame do
        {:array, _, path} -> [{:end_array, path} | ev]
        {:object, _, _, path} -> [{:end_object, path} | ev]
      end

    st = m(st, stack: stack, depth: depth - 1, mode: done_mode(stack))
    dispatch(rest, i + 1, data, c, st, ev)
  end

  defp done_mode([]), do: :done
  defp done_mode(_stack), do: :after

  defp emit_value(value, m(stack: stack) = st, ev),
    do: {m(st, mode: done_mode(stack), token: nil), [{:value, path(stack), value} | ev]}

  defp literal(rest, value, size, i, data, c, st, ev) do
    {st, ev} = emit_value(value, st, ev)
    dispatch(rest, i + size, data, c, st, ev)
  end

  # -- Comments -----------------------------------------------------------------

  defp line_comment(<<b, _::bits>> = rest, i, data, c, st, ev) when b in ~c"\n\r",
    do: dispatch(rest, i, data, c, m(st, token: nil), ev)

  defp line_comment(<<b, rest::bits>>, i, data, c, st, ev) when b < 0x80,
    do: line_comment(rest, i + 1, data, c, st, ev)

  defp line_comment(<<ch::utf8, rest::bits>>, i, data, c, st, ev),
    do: line_comment(rest, i + utf8_size(ch), data, c, st, ev)

  defp line_comment(<<>>, i, _data, _c, st, ev), do: {i, st, ev}
  defp line_comment(rest, i, _data, _c, st, ev), do: utf8_tail(rest, i, st, ev)

  defp block_comment(<<?*, ?/, rest::bits>>, i, data, c, st, ev),
    do: dispatch(rest, i + 2, data, c, m(st, token: nil), ev)

  defp block_comment(<<?*>>, i, _data, _c, st, ev), do: {i, st, ev}

  defp block_comment(<<b, rest::bits>>, i, data, c, st, ev) when b < 0x80,
    do: block_comment(rest, i + 1, data, c, st, ev)

  defp block_comment(<<ch::utf8, rest::bits>>, i, data, c, st, ev),
    do: block_comment(rest, i + utf8_size(ch), data, c, st, ev)

  defp block_comment(<<>>, i, _data, _c, st, ev), do: {i, st, ev}
  defp block_comment(rest, i, _data, _c, st, ev), do: utf8_tail(rest, i, st, ev)

  # -- Strings ------------------------------------------------------------------
  #
  # The string loop carries the decoded pieces of the current feed (`fresh`,
  # iodata) and the decoded size in arguments, so escapes do not rebuild the
  # token and the state record. The token keeps the role and the pieces of
  # earlier feeds (`acc`); `fresh` is written back when the chunk ends.

  # Printable ASCII that needs no escape handling inside a string.
  defguardp is_plain(b) when b >= 0x20 and b < 0x80 and b != ?" and b != ?\\

  defp resume_string(rest, i, data, c, st, ev) do
    {:string, _role, _acc, fresh, size} = m(st, :token)
    string(rest, i, i, fresh, size, data, c, st, ev)
  end

  # `start` is the index in `data` where the current run of literal bytes began.
  defp string(<<?", rest::bits>>, i, start, fresh, size, data, c, st, ev) do
    {:string, role, acc, _, _} = m(st, :token)
    {fresh, _size} = run(fresh, size, data, start, i, c, st)
    value = if acc == [], do: binary(fresh), else: binary([acc | fresh])

    case role do
      :value ->
        ev =
          if c.string_deltas and fresh != [] do
            delta = if acc == [], do: value, else: binary(fresh)
            [{:string_delta, path(m(st, :stack)), delta} | ev]
          else
            ev
          end

        {st, ev} = emit_value(value, st, ev)
        dispatch(rest, i + 1, data, c, st, ev)

      :key ->
        {st, ev} = key(value, i, st, ev)
        dispatch(rest, i + 1, data, c, st, ev)
    end
  end

  # Eight plain ASCII bytes at a time for long unescaped runs.
  defp string(<<a, b, d, e, f, g, h, j, rest::bits>>, i, start, fresh, size, data, c, st, ev)
       when is_plain(a) and is_plain(b) and is_plain(d) and is_plain(e) and is_plain(f) and
              is_plain(g) and is_plain(h) and is_plain(j),
       do: string(rest, i + 8, start, fresh, size, data, c, st, ev)

  defp string(<<?\\, rest::bits>>, i, start, fresh, size, data, c, st, ev) do
    {fresh, size} = run(fresh, size, data, start, i, c, st)
    escape(rest, i, fresh, size, data, c, st, ev)
  end

  defp string(<<b, _::bits>>, i, _start, _fresh, _size, _data, _c, st, _ev) when b < 0x20,
    do: fail(:syntax, :byte, i, st)

  defp string(<<b, rest::bits>>, i, start, fresh, size, data, c, st, ev) when b < 0x80,
    do: string(rest, i + 1, start, fresh, size, data, c, st, ev)

  defp string(<<ch::utf8, rest::bits>>, i, start, fresh, size, data, c, st, ev),
    do: string(rest, i + utf8_size(ch), start, fresh, size, data, c, st, ev)

  defp string(<<>>, i, start, fresh, size, data, c, st, ev) do
    {fresh, size} = run(fresh, size, data, start, i, c, st)
    {i, put_string(st, fresh, size), ev}
  end

  defp string(rest, i, start, fresh, size, data, c, st, ev) do
    {fresh, size} = run(fresh, size, data, start, i, c, st)
    utf8_tail(rest, i, put_string(st, fresh, size), ev)
  end

  # Writes the pieces of this feed back into the token (end of chunk).
  defp put_string(st, fresh, size) do
    {:string, role, acc, _, _} = m(st, :token)
    m(st, token: {:string, role, acc, fresh, size})
  end

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
  defp escape(<<ch, rest::bits>>, i, fresh, size, data, c, st, ev)
       when is_map_key(@simple_escapes, ch) do
    {fresh, size} = append(fresh, size, Map.fetch!(@simple_escapes, ch), 1, i, c, st)
    string(rest, i + 2, i + 2, fresh, size, data, c, st, ev)
  end

  defp escape(<<?u, a, b, d, e, rest::bits>>, i, fresh, size, data, c, st, ev) do
    case hex4(a, b, d, e) do
      cp when cp in 0xD800..0xDBFF ->
        surrogate(rest, cp, i, fresh, size, data, c, st, ev)

      cp when cp in 0xDC00..0xDFFF ->
        fail(:syntax, "lone low surrogate escape", i, st)

      cp when is_integer(cp) ->
        {fresh, size} = append(fresh, size, <<cp::utf8>>, utf8_size(cp), i, c, st)
        string(rest, i + 6, i + 6, fresh, size, data, c, st, ev)

      :error ->
        fail(:syntax, "invalid \\u escape", i, st)
    end
  end

  defp escape(<<?u, partial::bits>>, i, fresh, size, _data, _c, st, ev) do
    if all_hex?(partial),
      do: {i, put_string(st, fresh, size), ev},
      else: fail(:syntax, "invalid \\u escape", i, st)
  end

  defp escape(<<>>, i, fresh, size, _data, _c, st, ev), do: {i, put_string(st, fresh, size), ev}
  defp escape(_rest, i, _fresh, _size, _data, _c, st, _ev), do: fail(:syntax, :byte, i + 1, st)

  # `rest` follows a high-surrogate escape; a low-surrogate escape must follow.
  defp surrogate(<<?\\, ?u, a, b, d, e, rest::bits>>, hi, i, fresh, size, data, c, st, ev) do
    case hex4(a, b, d, e) do
      lo when lo in 0xDC00..0xDFFF ->
        cp = 0x10000 + ((hi - 0xD800) <<< 10) + (lo - 0xDC00)
        {fresh, size} = append(fresh, size, <<cp::utf8>>, 4, i, c, st)
        string(rest, i + 12, i + 12, fresh, size, data, c, st, ev)

      _ ->
        fail(:syntax, "high surrogate escape not followed by a low surrogate escape", i, st)
    end
  end

  defp surrogate(rest, _hi, i, fresh, size, _data, _c, st, ev) do
    if low_surrogate_prefix?(rest),
      do: {i, put_string(st, fresh, size), ev},
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

  # Adds the literal run data[start, i) to `fresh`, enforcing the size limit.
  defp run(fresh, size, _data, start, start, _c, _st), do: {fresh, size}

  defp run(fresh, size, data, start, i, c, st) do
    size = size + i - start

    if size > c.max_token_bytes do
      fail(:limit_exceeded, "string exceeds max_token_bytes (#{c.max_token_bytes})", i, st)
    end

    {[fresh | binary_part(data, start, i - start)], size}
  end

  # Adds a decoded escape. `piece` may be a byte, which cannot be an
  # improper-list tail.
  defp append(fresh, size, piece, piece_size, i, c, st) do
    size = size + piece_size

    if size > c.max_token_bytes do
      fail(:limit_exceeded, "string exceeds max_token_bytes (#{c.max_token_bytes})", i, st)
    end

    {[fresh, piece], size}
  end

  defp key(key, i, m(stack: [{:object, seen, _, path} | stack]) = st, ev) do
    if is_map_key(seen, key) do
      fail(:duplicate_key, {:duplicate_key, key, path}, i, st)
    end

    key_path = path ++ [key]
    stack = [{:object, Map.put(seen, key, true), key_path, path} | stack]
    {m(st, stack: stack, mode: :colon, token: nil), [{:key, key_path, key} | ev]}
  end

  # Returns a binary that does not reference a larger binary (the chunk).
  # A single piece (the common case: one run, no escapes) needs no
  # iolist_to_binary; it is copied only if it is a reference into the chunk
  # (on OTP 28+, slices of up to 64 bytes are already standalone).
  defp binary([[] | bin]) when is_binary(bin), do: detach(bin)
  defp binary([[] | [[] | bin]]) when is_binary(bin), do: detach(bin)
  defp binary(iodata), do: iodata |> IO.iodata_to_binary() |> detach()

  # On OTP 28+ a slice of up to 64 bytes is already a standalone binary.
  defp detach(bin) when byte_size(bin) <= 64, do: bin

  defp detach(bin) do
    if :binary.referenced_byte_size(bin) > byte_size(bin), do: :binary.copy(bin), else: bin
  end

  # -- Numbers ------------------------------------------------------------------

  defp number(<<b, rest::bits>>, i, start, nstate, data, c, st, ev) do
    case number_step(nstate, b) do
      :error ->
        fail(:syntax, :byte, i, st)

      :end ->
        # Resume at the terminator through a sub-binary of `data`. Rebuilding
        # `<<b, rest::bits>>` would copy the rest of the chunk for every number.
        number_end(i, start, data, c, st, ev)

      next ->
        number(rest, i + 1, start, next, data, c, st, ev)
    end
  end

  defp number(<<>>, i, start, nstate, data, c, st, ev) do
    {:number, _, acc, fresh, size} = m(st, :token)
    size = size + i - start

    if size > c.max_token_bytes do
      fail(:limit_exceeded, "number exceeds max_token_bytes (#{c.max_token_bytes})", i, st)
    end

    fresh = if i > start, do: [fresh | [binary_part(data, start, i - start)]], else: fresh
    {i, m(st, token: {:number, nstate, acc, fresh, size}), ev}
  end

  defp number_end(i, start, data, c, st, ev) do
    {:number, _, acc, fresh, _size} = m(st, :token)
    text = IO.iodata_to_binary([acc, fresh, binary_part(data, start, i - start)])
    value = number_value(text, i, st)
    {st, ev} = emit_value(value, st, ev)
    dispatch(binary_part(data, i, byte_size(data) - i), i, data, c, st, ev)
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

  # Same conversions and limits as the Formata.JSON.Backend decoder.
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
