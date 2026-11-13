defmodule Formata.Codec.JSON.Stream do
  @moduledoc """
  Incremental parser for a single JSON document that arrives in chunks.

  It is built for streamed output such as LLM token deltas. Chunks may be cut
  at any byte: inside a UTF-8 character, an escape sequence, a string, a
  number, a key, a literal, a comment, or between structural characters. The
  parser keeps an immutable state value and, after each chunk, returns the
  syntax events it can already confirm. It never re-parses earlier input.

  This is not a JSON Lines (NDJSON) parser: the input is one JSON text. To read
  JSON Lines, split the records and decode each one with
  `Formata.decode(line, :json)`.

  ## API

      {:ok, parser} = Formata.Codec.JSON.Stream.new()
      {:ok, events, parser} = Formata.Codec.JSON.Stream.feed(parser, ~s({"name": "Ad))
      # events == [{:start_object, []}, {:key, ["name"], "name"}]
      {:ok, events, parser} = Formata.Codec.JSON.Stream.feed(parser, ~s(a", "n": 4))
      # events == [{:value, ["name"], "Ada"}, {:key, ["n"], "n"}]
      {:ok, events} = Formata.Codec.JSON.Stream.finish(parser)
      # events == [{:value, ["n"], 4}, {:end_object, []}]

  `feed/2` returning `{:ok, [], parser}` means the input so far is a valid
  prefix that needs more bytes. It does **not** mean the document is valid. Only
  `finish/1` checks that exactly one complete JSON value was received, followed
  by nothing but whitespace (and comments, when enabled).

  `decode_stream/2` wraps `new/1`, `feed/2`, and `finish/1` as a lazy stream.

  ## Events

    * `{:start_object, path}` / `{:end_object, path}`
    * `{:start_array, path}` / `{:end_array, path}`
    * `{:key, path, key}` - a complete decoded key; `path` is the path of the
      field it names
    * `{:value, path, value}` - a complete scalar: string, integer, float,
      boolean, or `nil`
    * `{:string_delta, path, fragment}` - only with `string_deltas: true`

  `path` starts at `[]` for the root and lists object keys (strings) and array
  indexes (integers), as in `Formata.Error`.

  A number is emitted only once a byte that cannot continue it arrives (or at
  `finish/1`): `1` might still become `12` or `1.5`. Literals and strings are
  emitted as soon as they are complete.

  With `string_deltas: true`, string values (not keys) also produce
  `{:string_delta, path, fragment}` events with the decoded text received so
  far, at the end of each `feed/2` and before the final `{:value, ...}` event.
  Fragments contain only complete characters and complete escape sequences;
  joined, they equal the final string. Deltas are for previews: the string is
  not complete until its `{:value, path, string}` event.

  > #### Events are provisional {: .warning}
  >
  > Events report syntax the parser has recognized so far. Later bytes can
  > still make the document invalid, in which case `feed/2` or `finish/1`
  > returns an error and every event of this parse must be discarded or marked
  > as failed. Do not start side effects (for example an LLM tool call) from
  > partial events. Wait for `finish/1` to succeed, then validate the data
  > (`Formata.validate/3`) and apply your application's own confirmation.

  ## Agreement with `Formata.decode/3`

  For the same options, `finish/1` succeeds exactly when
  `Formata.decode(input, :json, opts)` succeeds on the concatenated input
  (within the resource limits below), and the events describe the same values.
  Duplicate keys (compared after unescaping) are rejected; the later value
  never overrides the earlier one. Error codes can differ: the stream reports
  the first problem in input order, and uses `:incomplete` for input that ends
  early, where `Formata.decode/3` reports `:syntax`.

  ## Options

    * `:comments` - accept `//` and `/* */` comments (default `false`)
    * `:trailing_commas` - accept one trailing comma in arrays and objects
      (default `false`)
    * `:string_deltas` - emit `:string_delta` events (default `false`)
    * `:max_depth` - maximum nesting of arrays and objects (default `1024`)
    * `:max_document_bytes` - maximum total input size (default 64 MiB)
    * `:max_token_bytes` - maximum size of a single string (decoded) or number
      (default 8 MiB)

  Comments and trailing commas behave exactly as in `Formata.Codec.JSON`.
  JSON5 is not supported here.

  ## Errors

  Errors are `Formata.Error` values with `kind: :parse`, `format: :json`, and
  `backend: Formata.Codec.JSON.Stream`:

    * `:syntax` - a byte that cannot continue a valid document
    * `:incomplete` - `finish/1` was called on a valid but unfinished prefix
      (open string, container, escape, number, comment, or no value at all)
    * `:duplicate_key` - with `details: %{key: key}` and the object's path
    * `:limit_exceeded` - a resource limit was hit, with `details: %{limit: name}`

  `location` holds the byte `offset` from the start of the whole stream, and the
  1-based `line` and `column` (in Unicode code points); chunk boundaries do not
  reset them. `path` is the location in the data where the error occurred.

  After an error, discard the parser.

  ## Memory and cost

  Each byte is scanned once. The parser keeps the container stack (with each
  container's path), the token in progress (an unfinished string or number,
  bounded by `:max_token_bytes`), at most 11 carried bytes of an incomplete
  character, escape, or literal, and the keys already seen in each open object
  (needed to reject duplicates). It does not keep the input. String and number
  pieces that reference a chunk are copied, so a parser state does not keep
  chunk binaries alive.

  Each `feed/2` call has a small fixed cost, so fewer, larger chunks are
  cheaper than many tiny ones. All events of a chunk are returned together:
  feeding a large document in one chunk materializes all of its events at
  once. Event paths are separate lists, so their memory grows with nesting
  depth. See `docs/design.md` for measurements.
  """

  alias Formata.Codec.JSON.Stream.Machine
  alias Formata.Error

  @typedoc "Opaque parser state."
  @opaque t :: %__MODULE__{}

  @type path :: [String.t() | non_neg_integer]
  @type event ::
          {:start_object, path}
          | {:end_object, path}
          | {:start_array, path}
          | {:end_array, path}
          | {:key, path, String.t()}
          | {:value, path, String.t() | number | boolean | nil}
          | {:string_delta, path, String.t()}

  @type errors :: [Error.t(), ...]

  defstruct comments: false,
            trailing_commas: false,
            string_deltas: false,
            max_depth: 1024,
            max_document_bytes: 64 * 1024 * 1024,
            max_token_bytes: 8 * 1024 * 1024,
            m: Machine.initial(),
            carry: <<>>,
            offset: 0,
            line: 1,
            column: 1

  defp options do
    [
      {:comments, &is_boolean/1, "a boolean"},
      {:trailing_commas, &is_boolean/1, "a boolean"},
      {:string_deltas, &is_boolean/1, "a boolean"},
      {:max_depth, &(is_integer(&1) and &1 > 0), "a positive integer"},
      {:max_document_bytes, &(is_integer(&1) and &1 > 0), "a positive integer"},
      {:max_token_bytes, &(is_integer(&1) and &1 > 0), "a positive integer"}
    ]
  end

  @doc """
  Creates a parser. See the module documentation for options.

      iex> {:ok, _parser} = Formata.Codec.JSON.Stream.new(comments: true)
      iex> {:error, [%Formata.Error{code: :invalid_option}]} =
      ...>   Formata.Codec.JSON.Stream.new(json5: true)
  """
  @spec new(keyword) :: {:ok, t} | {:error, errors}
  def new(opts \\ []) when is_list(opts) do
    with :ok <-
           Formata.Codec.check_options(opts, options(), backend: __MODULE__, format: :json) do
      {:ok, struct!(__MODULE__, opts)}
    end
  end

  @doc """
  Parses the next chunk.

  Returns the events completed by this chunk (possibly none) and the new
  parser, or an error if the input can no longer be a valid document.

      iex> {:ok, parser} = Formata.Codec.JSON.Stream.new()
      iex> {:ok, [{:start_array, []}], parser} = Formata.Codec.JSON.Stream.feed(parser, "[tr")
      iex> {:ok, [{:value, [0], true}], _parser} = Formata.Codec.JSON.Stream.feed(parser, "ue,")
  """
  @spec feed(t, binary) :: {:ok, [event], t} | {:error, errors}
  def feed(%__MODULE__{} = st, chunk) when is_binary(chunk) do
    received = st.offset + byte_size(st.carry) + byte_size(chunk)

    if received > st.max_document_bytes do
      error(
        :limit_exceeded,
        "document exceeds max_document_bytes (#{st.max_document_bytes})",
        st,
        st.carry,
        byte_size(st.carry),
        %{limit: :max_document_bytes}
      )
    else
      data = if st.carry == <<>>, do: chunk, else: st.carry <> chunk

      case Machine.run(data, st) do
        {:ok, consumed, m, events} ->
          {m, events} = Machine.settle(m, st.string_deltas, events)
          size = byte_size(data)

          # At most 11 bytes: on OTP 28+ such a slice is copied by the runtime
          # (sub-binaries of up to 64 bytes are not references), so it never
          # keeps the chunk alive.
          carry = binary_part(data, consumed, size - consumed)

          {line, column} = advance(st.line, st.column, data, consumed)

          {:ok, :lists.reverse(events),
           %{st | m: m, carry: carry, offset: st.offset + consumed, line: line, column: column}}

        {:error, code, message, index, at} ->
          machine_error(code, message, st, at, data, index)
      end
    end
  end

  @doc """
  Ends the input and checks that a complete document was received.

  Returns the remaining events (for example a root number, or the closing of
  the root container) or an error if the input is incomplete.

      iex> {:ok, parser} = Formata.Codec.JSON.Stream.new()
      iex> {:ok, [], parser} = Formata.Codec.JSON.Stream.feed(parser, "-12")
      iex> Formata.Codec.JSON.Stream.finish(parser)
      {:ok, [{:value, [], -12}]}

      iex> {:ok, parser} = Formata.Codec.JSON.Stream.new()
      iex> {:ok, _events, parser} = Formata.Codec.JSON.Stream.feed(parser, ~s({"a": "x))
      iex> {:error, [%Formata.Error{code: :incomplete}]} = Formata.Codec.JSON.Stream.finish(parser)
  """
  @spec finish(t) :: {:ok, [event]} | {:error, errors}
  def finish(%__MODULE__{} = st) do
    end_index = byte_size(st.carry)

    cond do
      st.carry != <<>> and Machine.token(st.m) == :line_comment ->
        error(:syntax, "invalid UTF-8", st, st.carry, 0, %{})

      st.carry != <<>> ->
        incomplete("unexpected end of input inside #{carry_context(st)}", st, end_index)

      true ->
        case Machine.finish_number(st.m) do
          {:ok, m, events} -> finish_mode(m, st, :lists.reverse(events))
          {:error, code, message, _index, at} -> machine_error(code, message, st, at, "", 0)
        end
    end
  end

  defp finish_mode(m, st, events) do
    token = Machine.token(m)

    cond do
      token not in [nil, :line_comment] ->
        what =
          case token do
            {:string, :key, _, _, _} -> "an object key"
            {:string, :value, _, _, _} -> "a string"
            {:number, _, _, _, _} -> "a number"
            :block_comment -> "a block comment"
          end

        incomplete("unexpected end of input inside #{what}", st, 0)

      Machine.mode(m) == :done ->
        {:ok, events}

      true ->
        case Machine.stack(m) do
          [] ->
            incomplete("unexpected end of input: no JSON value", st, 0)

          [frame | _] ->
            container = if elem(frame, 0) == :array, do: "an array", else: "an object"
            incomplete("unexpected end of input inside #{container}", st, 0)
        end
    end
  end

  defp carry_context(st) do
    case {Machine.token(st.m), st.carry} do
      {{:string, _, _, _, _}, _} -> "a string"
      {:block_comment, _} -> "a block comment"
      {_, "/" <> _} -> "a comment"
      _ -> "a literal"
    end
  end

  defp incomplete(message, st, index),
    do: error(:incomplete, message, st, st.carry, index, %{})

  @doc """
  Lazily parses an enumerable of binary chunks.

  Returns a stream of `{:ok, event}` items. If the input is invalid or
  incomplete, the last item is `{:error, errors}` and the stream stops; the
  upstream enumerable is halted and not read further. Chunks are read one at a
  time, only as the stream is consumed. The stream can be consumed once per
  enumeration of `chunks`.

      iex> ["[1, ", "2]"]
      ...> |> Formata.Codec.JSON.Stream.decode_stream()
      ...> |> Enum.to_list()
      [
        {:ok, {:start_array, []}},
        {:ok, {:value, [0], 1}},
        {:ok, {:value, [1], 2}},
        {:ok, {:end_array, []}}
      ]

      iex> [~s({"a": 1)] |> Formata.Codec.JSON.Stream.decode_stream() |> Enum.to_list()
      ...> |> List.last()
      ...> |> then(fn {:error, [error]} -> error.code end)
      :incomplete
  """
  @spec decode_stream(Enumerable.t(), keyword) :: Enumerable.t()
  def decode_stream(chunks, opts \\ []) when is_list(opts) do
    Elixir.Stream.resource(
      fn ->
        case new(opts) do
          {:ok, parser} ->
            {parser, &Enumerable.reduce(chunks, &1, fn chunk, _ -> {:suspend, chunk} end)}

          {:error, errors} ->
            {:error, errors}
        end
      end,
      &next/1,
      &halt_upstream/1
    )
  end

  defp next(:halted), do: {:halt, :halted}
  defp next({:error, errors}), do: {[{:error, errors}], :halted}

  defp next({parser, upstream}) do
    case upstream.({:cont, nil}) do
      {:suspended, chunk, upstream} when is_binary(chunk) ->
        case feed(parser, chunk) do
          {:ok, events, parser} ->
            {Enum.map(events, &{:ok, &1}), {parser, upstream}}

          {:error, errors} ->
            upstream.({:halt, nil})
            {[{:error, errors}], :halted}
        end

      {:suspended, chunk, upstream} ->
        upstream.({:halt, nil})

        errors = [
          Error.new(
            :unsupported,
            :invalid_chunk,
            "chunks must be binaries, got #{inspect(chunk)}",
            backend: __MODULE__,
            format: :json,
            details: %{chunk: chunk}
          )
        ]

        {[{:error, errors}], :halted}

      {done, _} when done in [:done, :halted] ->
        case finish(parser) do
          {:ok, events} -> {Enum.map(events, &{:ok, &1}), :halted}
          {:error, errors} -> {[{:error, errors}], :halted}
        end
    end
  end

  # Called when the consumer stops early: release the upstream enumerable.
  defp halt_upstream({_parser, upstream}) when is_function(upstream, 1),
    do: upstream.({:halt, nil})

  defp halt_upstream(_state), do: :ok

  # -- Errors and positions -------------------------------------------------------

  defp machine_error(:duplicate_key, {:duplicate_key, key, path}, st, _at, data, index) do
    {:error, [error] = _} =
      error(:duplicate_key, "duplicate object key #{inspect(key)}", st, data, index, %{key: key})

    {:error, [%{error | path: path}]}
  end

  defp machine_error(code, :byte, st, at, data, index) do
    message =
      if index < byte_size(data) do
        byte = :binary.at(data, index)
        str = <<byte>>

        if String.printable?(str),
          do: "unexpected byte #{inspect(byte, base: :hex)} (#{inspect(str)})",
          else: "unexpected byte #{inspect(byte, base: :hex)}"
      else
        "unexpected end of input"
      end

    machine_error(code, message, st, at, data, index)
  end

  defp machine_error(code, message, st, at, data, index) do
    details = if code == :limit_exceeded, do: %{limit: limit_name(message)}, else: %{}
    {:error, [error]} = error(code, message, st, data, index, details)
    {:error, [%{error | path: Machine.path(at.stack)}]}
  end

  defp limit_name("maximum nesting depth" <> _), do: :max_depth
  defp limit_name("document exceeds" <> _), do: :max_document_bytes
  defp limit_name(_), do: :max_token_bytes

  # `data` starts at `st.offset`; the error is at `data[index]`.
  defp error(code, message, st, data, index, details) do
    {line, column} = advance(st.line, st.column, binary_part(data, 0, index))
    offset = st.offset + index

    Error.error(:parse, code, "#{message} at position #{offset}",
      backend: __MODULE__,
      format: :json,
      path: Machine.path(Machine.stack(st.m)),
      location: %{offset: offset, line: line, column: column},
      details: details
    )
  end

  # Advances line/column over data[0, consumed): one pass, no copies. Columns
  # count code points (bytes that are not UTF-8 continuation bytes).
  #
  # Seven bytes at a time (56-bit words keep the arithmetic on BEAM small
  # integers) while a word has no newline:
  #   * a word without high bits is 7 ASCII code points;
  #   * otherwise its continuation bytes (bit 7 set, bit 6 clear) are counted
  #     with a mask and a shift-and-add popcount.
  # The newline test is the exact SWAR zero-byte test on `w ^ "\n\n..."`.
  # Words containing a newline are handled byte by byte.
  @highs 0x80808080808080
  @ones 0x01010101010101
  @newlines 0x0A0A0A0A0A0A0A
  @highs4 0x80808080
  @ones4 0x01010101
  @newlines4 0x0A0A0A0A

  defp advance(line, column, data, consumed), do: advance_bytes(data, consumed, line, column)

  defp advance(line, column, consumed),
    do: advance_bytes(consumed, byte_size(consumed), line, column)

  defp advance_bytes(_data, 0, line, column), do: {line, column}

  defp advance_bytes(<<w::56, rest::bits>>, n, line, column)
       when n >= 7 and Bitwise.band(w, @highs) == 0 and
              Bitwise.band(Bitwise.bxor(w, @newlines) - @ones, @highs) == 0,
       do: advance_bytes(rest, n - 7, line, column + 7)

  defp advance_bytes(<<w::56, rest::bits>> = data, n, line, column) when n >= 7 do
    import Bitwise
    y = bxor(w, @newlines)

    if band(band(y - @ones, bnot(y)), @highs) == 0 do
      continuation = band(w, bnot(w <<< 1)) &&& @highs
      advance_bytes(rest, n - 7, line, column + 7 - popcount_high_bits(continuation))
    else
      advance_word(data, 7, n, line, column)
    end
  end

  # The same for 4-byte words (short chunks such as token deltas).
  defp advance_bytes(<<w::32, rest::bits>> = data, n, line, column) when n >= 4 do
    import Bitwise
    y = bxor(w, @newlines4)

    cond do
      band(band(y - @ones4, bnot(y)), @highs4) != 0 ->
        advance_word(data, 4, n, line, column)

      band(w, @highs4) == 0 ->
        advance_bytes(rest, n - 4, line, column + 4)

      true ->
        continuation = band(w, bnot(w <<< 1)) &&& @highs4
        advance_bytes(rest, n - 4, line, column + 4 - popcount_high_bits(continuation))
    end
  end

  defp advance_bytes(data, n, line, column), do: advance_word(data, n, n, line, column)

  # The next `k` bytes byte by byte (a word containing a newline, or the last
  # bytes), then back to word steps.
  defp advance_word(data, 0, n, line, column), do: advance_bytes(data, n, line, column)

  defp advance_word(<<?\n, rest::bits>>, k, n, line, _column),
    do: advance_word(rest, k - 1, n - 1, line + 1, 1)

  defp advance_word(<<b, rest::bits>>, k, n, line, column) when b in 0x80..0xBF,
    do: advance_word(rest, k - 1, n - 1, line, column)

  defp advance_word(<<_, rest::bits>>, k, n, line, column),
    do: advance_word(rest, k - 1, n - 1, line, column + 1)

  # Number of set high bits (0x80 positions) in a 56-bit word.
  defp popcount_high_bits(x) do
    import Bitwise
    x = x >>> 7
    x = x + (x >>> 8)
    x = x + (x >>> 16)
    x = x + (x >>> 32)
    x &&& 0xFF
  end
end
