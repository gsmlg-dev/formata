defmodule Formata.Codec.JSON.StreamTest do
  use ExUnit.Case, async: true

  alias Formata.Codec.JSON.Stream, as: JSONStream
  alias Formata.Error

  doctest Formata.Codec.JSON.Stream

  # -- Helpers --------------------------------------------------------------------

  # Feeds `chunks` and finishes; returns {:ok, events} or {:error, errors}.
  defp parse(chunks, opts \\ []) do
    {:ok, parser} = JSONStream.new(opts)

    chunks
    |> Enum.reduce_while({:ok, parser, []}, fn chunk, {:ok, parser, acc} ->
      case JSONStream.feed(parser, chunk) do
        {:ok, events, parser} -> {:cont, {:ok, parser, [acc | events]}}
        {:error, errors} -> {:halt, {:error, errors}}
      end
    end)
    |> case do
      {:ok, parser, acc} ->
        case JSONStream.finish(parser) do
          {:ok, events} -> {:ok, List.flatten([acc | events])}
          error -> error
        end

      error ->
        error
    end
  end

  # Rebuilds the decoded value from events.
  defp build(events) do
    {[value], []} =
      Enum.reduce(events, {[], []}, fn
        {:start_object, _}, {values, stack} ->
          {values, [{:object, []} | stack]}

        {:start_array, _}, {values, stack} ->
          {values, [{:array, []} | stack]}

        {:key, _, key}, {values, [{:object, pairs} | stack]} ->
          {values, [{:object, [key | pairs]} | stack]}

        {:end_object, _}, {values, [{:object, pairs} | stack]} ->
          push(values, stack, object(pairs))

        {:end_array, _}, {values, [{:array, items} | stack]} ->
          push(values, stack, Enum.reverse(items))

        {:value, _, value}, {values, stack} ->
          push(values, stack, value)

        {:string_delta, _, _}, acc ->
          acc
      end)

    value
  end

  defp object(pairs) do
    pairs |> Enum.reverse() |> Enum.chunk_every(2) |> Map.new(fn [k, v] -> {k, v} end)
  end

  defp push(values, [], value), do: {[value | values], []}

  defp push(values, [{:array, items} | stack], value),
    do: {values, [{:array, [value | items]} | stack]}

  defp push(values, [{:object, [key | pairs]} | stack], value),
    do: {values, [{:object, [value, key | pairs]} | stack]}

  defp bytes(doc), do: for(<<b::binary-1 <- doc>>, do: b)

  defp splits(doc) do
    for i <- 0..byte_size(doc),
        do: [binary_part(doc, 0, i), binary_part(doc, i, byte_size(doc) - i)]
  end

  defp random_chunks(doc, seed) do
    :rand.seed(:exsss, {seed, seed * 7 + 1, seed * 13 + 2})
    chop(doc, [])
  end

  defp chop(<<>>, acc), do: Enum.reverse(acc)

  defp chop(doc, acc) do
    n = min(:rand.uniform(7) - 1, byte_size(doc))
    chunk = binary_part(doc, 0, n)
    chop(binary_part(doc, n, byte_size(doc) - n), [chunk | acc])
  end

  # Strict and extended documents shared by the differential tests.
  @valid [
    ~s({"name": "Ada", "n": [1, -0.12e+34, true, false, null, {}], "x": {"y": []}}),
    ~s("long #{String.duplicate("abc ", 50)}"),
    ~s(["é", "😀", "\\u00e9", "\\ud83d\\ude00", "a\\\\b\\"c\\/\\b\\f\\n\\r\\t", "日本語"]),
    ~s({"\\u0061b": 1, "ab\\u0063": 2}),
    ~s([[[[[]]]], [[{"a": [[]]}]]]),
    "0",
    "-0",
    "-0.0",
    "1E5",
    "1e-5",
    "1e-400",
    "-1e-400",
    "123456789012345678901234567890",
    "  \n\t\r 42 \n",
    ~s(""),
    "true",
    "null",
    "[]",
    "{}"
  ]

  @invalid [
    "",
    "   ",
    ~s({"a" 1}),
    ~s({"a":1,"a":2}),
    ~s({"a":{"b":1,"\\u0062":2}}),
    "{}{}",
    "1 2",
    "[1,]",
    "[1,,2]",
    "{,}",
    ~s({"a":1,}),
    "01",
    "-",
    "1.",
    "1e",
    "1e+",
    ".5",
    "+1",
    "tru",
    "trux",
    "nul",
    ~s("abc),
    ~s("\\u12"),
    ~s("\\uZZZZ"),
    ~s("\\ud83d"),
    ~s("\\ud83d\\u0041"),
    ~s("\\udc00"),
    ~s("\\x"),
    "\"\x01\"",
    "\"\xFF\"",
    "\"\xC3\"",
    "\"\xE0\x80\x80\"",
    "\"\xED\xA0\x80\"",
    "[1, 2",
    ~s({"a": [}),
    "]",
    "// c\n1",
    "1e400",
    "NaN",
    "'a'"
  ]

  @extended_valid [
    "// head\n{\"a\": /* x */ [1, 2,], \"b\": \"//not\", /* c */ } // tail",
    "/* only */ 1 /* and */ // trailing",
    "[1 /* * / */, 2,]\r\n",
    ~s({"u": "https://example.com/a//b", "c": "/* x */",})
  ]

  @extended_invalid [
    "/* open",
    "1 /",
    "[1/**/2]",
    "tr/**/ue",
    "[1,,]",
    "{,}",
    "/* a /* b */ */ 1",
    "1 // \xFF"
  ]

  defp assert_agrees(doc, opts) do
    oneshot = Formata.decode(doc, :json, opts)
    whole = parse([doc], opts)

    case oneshot do
      {:ok, value} ->
        assert {:ok, events} = whole, "stream rejected #{inspect(doc)}: #{inspect(whole)}"
        assert build(events) === value, "value mismatch for #{inspect(doc)}"

      {:error, _} ->
        assert {:error, [%Error{kind: :parse}]} = whole, "stream accepted #{inspect(doc)}"
    end

    for chunks <- [bytes(doc) | splits(doc)] ++ Enum.map(1..5, &random_chunks(doc, &1)) do
      assert parse(chunks, opts) |> strip() == strip(whole),
             "chunking #{inspect(chunks)} changed the result"
    end
  end

  # Removes deltas (they depend on chunking) and keeps error code/offset only.
  defp strip({:ok, events}), do: {:ok, Enum.reject(events, &match?({:string_delta, _, _}, &1))}

  defp strip({:error, errors}),
    do: {:error, Enum.map(errors, &{&1.code, &1.location, &1.path})}

  # -- Differential tests -------------------------------------------------------------

  describe "agrees with Formata.decode/3 under any chunking" do
    test "strict valid documents" do
      for doc <- @valid, do: assert_agrees(doc, [])
    end

    test "strict invalid documents" do
      for doc <- @invalid, do: assert_agrees(doc, [])
    end

    test "extended documents under all option combinations" do
      for doc <- @extended_valid ++ @extended_invalid ++ @valid ++ @invalid,
          opts <- [
            [comments: true],
            [trailing_commas: true],
            [comments: true, trailing_commas: true]
          ] do
        assert_agrees(doc, opts)
      end
    end

    test "valid extended documents are accepted" do
      for doc <- @extended_valid do
        assert {:ok, _} = parse(bytes(doc), comments: true, trailing_commas: true)
      end
    end

    test "random documents" do
      for seed <- 1..40 do
        :rand.seed(:exsss, {seed, 2, 3})
        value = random_value(4)
        {:ok, doc} = Formata.encode(value, :json, pretty: rem(seed, 2) == 0)
        assert {:ok, events} = parse(random_chunks(doc, seed))
        assert build(events) === value
      end
    end
  end

  defp random_value(0), do: random_scalar()

  defp random_value(depth) do
    case :rand.uniform(4) do
      1 -> Enum.map(1..:rand.uniform(4), fn _ -> random_value(depth - 1) end)
      2 -> Map.new(1..:rand.uniform(4), fn i -> {"k#{i}é", random_value(depth - 1)} end)
      _ -> random_scalar()
    end
  end

  defp random_scalar do
    Enum.random([
      nil,
      true,
      false,
      :rand.uniform(1_000_000) - 500_000,
      :rand.uniform() * 1.0e10 - 5.0e9,
      "plain",
      "esc \" \\ \n \t \u0001",
      "uni é 日本 😀",
      ""
    ])
  end

  # -- Event protocol -------------------------------------------------------------------

  describe "events" do
    test "are emitted as soon as they are known" do
      {:ok, p} = JSONStream.new()
      assert {:ok, [{:start_object, []}], p} = JSONStream.feed(p, "{")
      assert {:ok, [], p} = JSONStream.feed(p, ~s("ti))
      assert {:ok, [{:key, ["title"], "title"}], p} = JSONStream.feed(p, ~s(tle"))
      assert {:ok, [], p} = JSONStream.feed(p, ": 1")
      # The number might continue.
      assert {:ok, [], p} = JSONStream.feed(p, "2")
      assert {:ok, [{:value, ["title"], 12}], p} = JSONStream.feed(p, ", ")

      assert {:ok, [{:key, ["l"], "l"}, {:start_array, ["l"]}, {:value, ["l", 0], true}], p} =
               JSONStream.feed(p, ~s("l": [true))

      assert {:ok, [{:end_array, ["l"]}, {:end_object, []}], p} = JSONStream.feed(p, "]}")
      assert {:ok, []} = JSONStream.finish(p)
    end

    test "empty chunks are no-ops" do
      {:ok, p} = JSONStream.new()
      assert {:ok, [], p} = JSONStream.feed(p, "")
      assert {:ok, [{:start_array, []}], p} = JSONStream.feed(p, "[")
      assert {:ok, [], p} = JSONStream.feed(p, "")
      assert {:ok, [{:end_array, []}], p} = JSONStream.feed(p, "]")
      assert {:ok, [], p} = JSONStream.feed(p, "")
      assert {:ok, []} = JSONStream.finish(p)
    end

    test "a root number is emitted by finish" do
      {:ok, p} = JSONStream.new()
      assert {:ok, [], p} = JSONStream.feed(p, "-0.12e+3")
      assert {:ok, [], p} = JSONStream.feed(p, "4")
      assert {:ok, [{:value, [], -1.2e33}]} = JSONStream.finish(p)
    end

    test "invalid prefixes fail immediately, valid prefixes wait" do
      {:ok, p} = JSONStream.new()
      assert {:ok, _, p2} = JSONStream.feed(p, ~s({"a":))
      assert {:ok, [], _} = JSONStream.feed(p2, " ")
      assert {:error, [%Error{code: :syntax}]} = JSONStream.feed(p, ~s({"a" 1}))
      assert {:ok, [], p3} = JSONStream.feed(p, "tr")
      assert {:error, [%Error{code: :syntax, location: %{offset: 0}}]} = JSONStream.feed(p3, "x")
      assert {:ok, [], p4} = JSONStream.feed(p, "1e")
      assert {:ok, [], p4} = JSONStream.feed(p4, "+")
      assert {:error, [%Error{code: :syntax, location: %{offset: 3}}]} = JSONStream.feed(p4, "x")
      assert {:ok, [], p5} = JSONStream.feed(p, ~s("\\u00))
      assert {:error, [%Error{code: :syntax}]} = JSONStream.feed(p5, "G0\"")
      # An overlong UTF-8 lead is rejected before its last byte arrives.
      assert {:error, [%Error{code: :syntax}]} = JSONStream.feed(p, "\"\xE0\x80")
    end

    test "string deltas" do
      doc = ~s({"k": "héllo \\u00e9 \\ud83d\\ude00 wörld", "n": "x"})

      for chunks <- [[doc], bytes(doc) | splits(doc)] do
        assert {:ok, events} = parse(chunks, string_deltas: true)

        deltas = for {:string_delta, ["k"], d} <- events, do: d
        assert Enum.all?(deltas, &String.valid?/1)
        assert Enum.join(deltas) == "héllo é 😀 wörld"
        assert {:value, ["k"], "héllo é 😀 wörld"} in events

        # Every delta precedes the value; keys produce no deltas.
        [value_index] =
          for {{:value, ["k"], _}, i} <- Enum.with_index(events), do: i

        assert Enum.all?(Enum.with_index(events), fn
                 {{:string_delta, ["k"], _}, i} -> i < value_index
                 {{:string_delta, path, _}, _} -> path == ["n"]
                 _ -> true
               end)
      end
    end

    test "deltas arrive before the string is complete" do
      {:ok, p} = JSONStream.new(string_deltas: true)

      assert {:ok, [{:start_array, []}, {:string_delta, [0], "Hel"}], p} =
               JSONStream.feed(p, ~s(["Hel))

      # Incomplete UTF-8 is held back.
      assert {:ok, [{:string_delta, [0], "lo "}], p} = JSONStream.feed(p, "lo \xC3")

      assert {:ok, [{:string_delta, [0], "é"}, {:value, [0], "Hello é"}], _p} =
               JSONStream.feed(p, "\xA9\"")
    end
  end

  # -- Errors ---------------------------------------------------------------------------

  describe "errors" do
    test "duplicate keys carry the object path and key" do
      assert {:error,
              [%Error{kind: :parse, code: :duplicate_key, path: ["a"], details: %{key: "b"}}]} =
               parse(bytes(~s({"a": {"b": 1, "\\u0062": 2}})))
    end

    test "locations count across chunk boundaries" do
      doc = "{\n  \"é\": [1,\n   2 x]}"
      {:error, [expected]} = Formata.decode(doc, :json)

      for chunks <- [[doc], bytes(doc) | splits(doc)] do
        assert {:error, [%Error{code: :syntax} = error]} = parse(chunks)
        assert error.location == %{offset: 19, line: 3, column: 6}
        assert error.location.offset == expected.location.offset
        assert error.path == ["é", 1]
      end
    end

    test "incomplete input is reported by finish" do
      for {doc, text} <- [
            {"", "no JSON value"},
            {"  ", "no JSON value"},
            {~s("abc), "inside a string"},
            {~s({"ab), "inside an object key"},
            {~s("a\\u00), "inside a string"},
            {~s("\\ud83d), "inside a string"},
            {"1e+", "inside a number"},
            {"-", "inside a number"},
            {"[1, {", "inside an object"},
            {"[", "inside an array"},
            {"tru", "inside a literal"},
            {"\"\xE2\x82", "inside a string"}
          ] do
        assert {:error,
                [%Error{kind: :parse, code: :incomplete, message: message, location: loc}]} =
                 parse(bytes(doc))

        assert message =~ text, "#{inspect(doc)}: #{message}"
        assert loc.offset == byte_size(doc)
      end

      assert {:error,
              [
                %Error{
                  code: :incomplete,
                  message: "unexpected end of input inside a block comment" <> _
                }
              ]} =
               parse(["1 /* x"], comments: true)

      assert {:ok, _} = parse(["1 // x"], comments: true)
    end

    test "options" do
      assert {:error, [%Error{kind: :unsupported, code: :invalid_option}]} =
               JSONStream.new(comments: 1)

      assert {:error, [%Error{code: :invalid_option}]} = JSONStream.new(max_depth: 0)
      assert {:error, [%Error{code: :invalid_option}]} = JSONStream.new(json5: true)
    end
  end

  # -- Limits ---------------------------------------------------------------------------

  describe "resource limits" do
    test "max_depth" do
      assert {:ok, _} = parse(["[[[]]]"], max_depth: 3)

      assert {:error,
              [
                %Error{
                  code: :limit_exceeded,
                  details: %{limit: :max_depth},
                  location: %{offset: 3}
                }
              ]} =
               parse(["[[[[]]]]"], max_depth: 3)
    end

    test "max_document_bytes" do
      {:ok, p} = JSONStream.new(max_document_bytes: 10)
      assert {:ok, _, p} = JSONStream.feed(p, "[1, 2, 3")
      assert {:ok, _, p} = JSONStream.feed(p, "]")

      assert {:error, [%Error{code: :limit_exceeded, details: %{limit: :max_document_bytes}}]} =
               JSONStream.feed(p, "  ")
    end

    test "max_token_bytes for strings and numbers" do
      assert {:ok, _} = parse([~s("abcd")], max_token_bytes: 4)

      assert {:error, [%Error{code: :limit_exceeded, details: %{limit: :max_token_bytes}}]} =
               parse(bytes(~s("abcde")), max_token_bytes: 4)

      assert {:error, [%Error{code: :limit_exceeded}]} = parse([~s("abcde")], max_token_bytes: 4)

      assert {:error, [%Error{code: :limit_exceeded}]} =
               parse(bytes("123456"), max_token_bytes: 4)
    end

    test "the integer digit limit matches the one-shot decoder" do
      ok = String.duplicate("9", 1024)
      too_long = String.duplicate("9", 1025)
      assert {:ok, [{:value, [], _}]} = parse([ok])
      assert {:error, _} = Formata.decode(too_long, :json)
      assert {:error, [%Error{code: :syntax}]} = parse([too_long])
    end

    test "parser state does not retain chunk binaries" do
      big = String.duplicate("x", 100_000)
      {:ok, p} = JSONStream.new()
      {:ok, _, p} = JSONStream.feed(p, ~s([") <> big <> "ab")
      {:string, :value, acc, [], _} = p.token

      for piece <- List.flatten(acc), is_binary(piece) do
        assert :binary.referenced_byte_size(piece) == byte_size(piece)
      end

      assert :binary.referenced_byte_size(p.carry) == byte_size(p.carry)
    end
  end

  # -- decode_stream ----------------------------------------------------------------------

  describe "decode_stream/2" do
    test "is lazy and pulls chunks only as events are consumed" do
      parent = self()

      chunks =
        Stream.map(["[1", ", 2", ", 3", "]"], fn chunk ->
          send(parent, {:pulled, chunk})
          chunk
        end)

      stream = JSONStream.decode_stream(chunks)
      refute_received {:pulled, _}

      assert [{:ok, {:start_array, []}}] = Enum.take(stream, 1)
      assert_received {:pulled, "[1"}
      refute_received {:pulled, ", 2"}
    end

    test "stops at the first error and halts upstream" do
      parent = self()

      chunks =
        Stream.resource(
          fn -> ["[1", " x", "]", "]"] end,
          fn
            [] -> {:halt, []}
            [chunk | rest] -> {[chunk], rest}
          end,
          fn rest -> send(parent, {:upstream_closed, rest}) end
        )

      assert [
               {:ok, {:start_array, []}},
               {:error, [%Error{code: :syntax, location: %{offset: 3}}]}
             ] =
               chunks |> JSONStream.decode_stream() |> Enum.to_list()

      assert_received {:upstream_closed, ["]", "]"]}
    end

    test "halts upstream when the consumer stops early" do
      parent = self()

      chunks =
        Stream.resource(
          fn -> ["[1,", "2,", "3]"] end,
          fn
            [] -> {:halt, []}
            [chunk | rest] -> {[chunk], rest}
          end,
          fn rest -> send(parent, {:upstream_closed, rest}) end
        )

      assert [{:ok, {:start_array, []}}] = chunks |> JSONStream.decode_stream() |> Enum.take(1)
      assert_received {:upstream_closed, ["2,", "3]"]}
    end

    test "reports incomplete input at the end" do
      assert [{:ok, {:start_array, []}}, {:error, [%Error{code: :incomplete}]}] =
               ["[", " "] |> JSONStream.decode_stream() |> Enum.to_list()
    end

    test "invalid options and chunks" do
      assert [{:error, [%Error{code: :invalid_option}]}] =
               ["1"] |> JSONStream.decode_stream(bad: 1) |> Enum.to_list()

      assert [{:error, [%Error{code: :invalid_chunk}]}] =
               [~c"1"] |> JSONStream.decode_stream() |> Enum.to_list()
    end

    test "passes options through" do
      assert [{:ok, {:value, [], 1}}] =
               ["1 // c"] |> JSONStream.decode_stream(comments: true) |> Enum.to_list()
    end
  end
end
