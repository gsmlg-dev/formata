# Benchmark for Formata.Codec.JSON.Stream.
#
#     MIX_ENV=test mix run bench/json_stream.exs            # all workloads
#     MIX_ENV=test mix run bench/json_stream.exs structured # one workload
#
# Every measurement runs in a fresh process and reports the median of several
# repetitions:
#
#   ms          wall-clock time
#   reductions  BEAM reductions of the parsing process
#   GCs         garbage collections in the VM during the run (the VM is
#               otherwise idle, so these are the parsing process's)
#   alloc (kw)  heap words reclaimed by GC during the run, in thousands (a
#               proxy for allocation; the VM is otherwise idle)
#
# Rows marked "events" feed chunks with `new/1`, `feed/2`, `finish/1` and
# discard the events; "deltas" enables `string_deltas: true`;
# "decode_stream" consumes `decode_stream/2` with Stream.run/1. Comparison
# rows decode the complete value without events: Formata.decode/3 (one shot),
# OTP's :json.decode/1 (one shot) and :json.decode_start/3 +
# decode_continue/2 (incremental), and re-decoding the accumulated buffer
# after every chunk.

alias Formata.Codec.JSON.Stream, as: JSONStream

defmodule Bench do
  def chunks(doc, :whole), do: [doc]

  def chunks(doc, {:fixed, size}) do
    for i <- 0..div(byte_size(doc) - 1, size),
        do: binary_part(doc, i * size, min(size, byte_size(doc) - i * size))
  end

  # LLM-style token deltas: random sizes in `range`, fixed seed.
  def chunks(doc, {:tokens, first..last//_}) do
    :rand.seed(:exsss, {1, 2, 3})
    take(doc, first, last, [])
  end

  defp take(<<>>, _first, _last, acc), do: Enum.reverse(acc)

  defp take(doc, first, last, acc) do
    n = min(first - 1 + :rand.uniform(last - first + 1), byte_size(doc))
    take(binary_part(doc, n, byte_size(doc) - n), first, last, [binary_part(doc, 0, n) | acc])
  end

  def label(:whole), do: "whole document"
  def label({:fixed, n}), do: "#{n}-byte chunks"
  def label({:tokens, a..b//_}), do: "random #{a}-#{b} B chunks"

  def events(chunks, opts) do
    {:ok, p} = JSONStream.new(opts)

    p =
      Enum.reduce(chunks, p, fn chunk, p ->
        {:ok, _events, p} = JSONStream.feed(p, chunk)
        p
      end)

    {:ok, _} = JSONStream.finish(p)
  end

  def decode_stream(chunks, opts) do
    chunks |> JSONStream.decode_stream(opts) |> Stream.run()
  end

  def otp_incremental([first | rest]) do
    rest
    |> Enum.reduce(:json.decode_start(first, :ok, %{}), fn
      chunk, {:continue, state} -> :json.decode_continue(chunk, state)
    end)
    |> case do
      {:continue, state} -> :json.decode_continue(:end_of_input, state)
      done -> done
    end
  end

  def redecode(chunks) do
    Enum.reduce(chunks, "", fn chunk, buffer ->
      buffer = buffer <> chunk
      _ = Formata.decode(buffer, :json)
      buffer
    end)
  end

  def measure(fun) do
    runs = runs(fun, [], 0)

    median = fn key ->
      runs |> Enum.map(&Map.fetch!(&1, key)) |> Enum.sort() |> Enum.at(div(length(runs), 2))
    end

    %{ms: median.(:ms), reds: median.(:reds), gcs: median.(:gcs), words: median.(:words)}
  end

  # At least 5 and at most 15 repetitions, or until about one second is spent.
  defp runs(_fun, acc, spent) when length(acc) >= 15 or (length(acc) >= 5 and spent > 1000),
    do: acc

  defp runs(fun, acc, spent) do
    run = once(fun)
    runs(fun, [run | acc], spent + run.ms)
  end

  defp once(fun) do
    Task.async(fn ->
      :erlang.garbage_collect()
      {:reductions, r0} = :erlang.process_info(self(), :reductions)
      {gc0, w0, _} = :erlang.statistics(:garbage_collection)
      {us, _} = :timer.tc(fun)
      {gc1, w1, _} = :erlang.statistics(:garbage_collection)
      {:reductions, r1} = :erlang.process_info(self(), :reductions)
      %{ms: us / 1000, reds: r1 - r0, gcs: gc1 - gc0, words: div(w1 - w0, 1000)}
    end)
    |> Task.await(:infinity)
  end

  def row(workload, chunking, mode, chunks, %{ms: ms, reds: reds, gcs: gcs, words: words}) do
    IO.puts(
      "| #{workload} | #{chunking} | #{mode} | #{chunks} | " <>
        "#{:erlang.float_to_binary(ms * 1.0, decimals: 2)} | #{reds} | #{gcs} | #{words} |"
    )
  end
end

# -- Documents ------------------------------------------------------------------

item = fn i ->
  %{
    "id" => i,
    "name" => "item #{i} — ünïcödé 😀",
    "tags" => ["a", "b", "c"],
    "score" => i * 1.5,
    "ok" => rem(i, 2) == 0,
    "note" => String.duplicate("lorem ipsum ", 8)
  }
end

{:ok, structured} = Formata.encode(%{"items" => Enum.map(1..2000, item)}, :json)
{:ok, pretty} = Formata.encode(%{"items" => Enum.map(1..500, item)}, :json, pretty: true)

prose =
  "The quick brown fox — «jumps» over the lazy dog. Ünïcödé, 日本語, emoji 😀.\n" <>
    "Quoted \"text\", a backslash \\ and a tab\t.\n"

{:ok, llm_tool} =
  Formata.encode(
    %{
      "tool" => "search",
      "arguments" => %{
        "query" => "incremental JSON parsing in Elixir",
        "filters" => %{"lang" => ["en", "de"], "max_results" => 20, "safe" => true},
        "context" => String.duplicate(prose, 40),
        "history" =>
          Enum.map(1..10, fn i -> %{"role" => "user", "turn" => i, "content" => prose} end)
      }
    },
    :json
  )

{:ok, long_string} = Formata.encode(%{"text" => String.duplicate(prose, 2500)}, :json)

escaped_unicode =
  ~s({"s": [) <>
    Enum.map_join(1..2000, ", ", fn _ ->
      ~s("\\u00e9\\u65e5\\u672c\\ud83d\\ude00\\u0041\\n\\t\\"")
    end) <>
    "]}"

deep =
  String.duplicate(~s({"a": [), 400) <> "1" <> String.duplicate("]}", 400)

docs = %{
  "structured" => structured,
  "pretty" => pretty,
  "llm_tool" => llm_tool,
  "long_string" => long_string,
  "escaped_unicode" => escaped_unicode,
  "deep" => deep
}

# {workload, chunkings, modes}
plan = [
  {"structured",
   [:whole, {:fixed, 65_536}, {:fixed, 4096}, {:tokens, 1..256}, {:tokens, 1..16}, {:fixed, 1}],
   [:events, :otp_incremental]},
  {"pretty", [:whole, {:fixed, 4096}, {:tokens, 1..16}], [:events]},
  {"llm_tool", [:whole, {:tokens, 1..256}, {:tokens, 1..16}, {:fixed, 1}],
   [:events, :deltas, :decode_stream, :otp_incremental, :redecode]},
  {"long_string", [:whole, {:fixed, 4096}, {:tokens, 1..16}],
   [:events, :deltas, :otp_incremental]},
  {"escaped_unicode", [:whole, {:tokens, 1..16}], [:events, :deltas]},
  {"deep", [:whole, {:tokens, 1..16}], [:events]}
]

only = System.argv()

IO.puts("Elixir #{System.version()} / OTP #{System.otp_release()}\n")
IO.puts("| workload | chunking | mode | chunks | ms | reductions | GCs | alloc (kw) |")
IO.puts("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |")

for {name, chunkings, modes} <- plan, only == [] or name in only do
  doc = Map.fetch!(docs, name)
  workload = "#{name} (#{div(byte_size(doc), 1024)} KiB)"

  Bench.row(
    workload,
    "whole document",
    "Formata.decode/3",
    1,
    Bench.measure(fn -> {:ok, _} = Formata.decode(doc, :json) end)
  )

  Bench.row(
    workload,
    "whole document",
    ":json.decode/1",
    1,
    Bench.measure(fn -> :json.decode(doc) end)
  )

  for chunking <- chunkings, mode <- modes do
    chunks = Bench.chunks(doc, chunking)
    n = length(chunks)

    fun =
      case mode do
        :events -> fn -> Bench.events(chunks, []) end
        :deltas -> fn -> Bench.events(chunks, string_deltas: true) end
        :decode_stream -> fn -> Bench.decode_stream(chunks, []) end
        :otp_incremental -> fn -> Bench.otp_incremental(chunks) end
        :redecode -> fn -> Bench.redecode(chunks) end
      end

    skip? = mode in [:otp_incremental, :redecode] and n > 30_000

    unless skip? do
      label =
        case mode do
          :events -> "events"
          :deltas -> "events + string_deltas"
          :decode_stream -> "decode_stream"
          :otp_incremental -> ":json decode_continue"
          :redecode -> "re-decode buffer"
        end

      Bench.row(workload, Bench.label(chunking), label, n, Bench.measure(fun))
    end
  end
end
