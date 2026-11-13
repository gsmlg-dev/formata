# Incremental JSON parser cost by chunk size.
#
#     MIX_ENV=test mix run bench/json_stream.exs
#
# Parses the same document once with Formata.decode/3 and with
# Formata.Codec.JSON.Stream at several chunk sizes, and compares against the
# naive approach of re-decoding the accumulated buffer after every chunk.
# Times are wall-clock medians of 5 runs on the current machine; allocation is
# the parsing process's total heap growth reported by :erlang.process_info/2.

alias Formata.Codec.JSON.Stream, as: JSONStream

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

doc = fn n -> Formata.encode(%{"items" => Enum.map(1..n, item)}, :json) |> elem(1) end

chunks = fn doc, size ->
  for i <- 0..div(byte_size(doc) - 1, size),
      do: binary_part(doc, i * size, min(size, byte_size(doc) - i * size))
end

stream_parse = fn chunks ->
  {:ok, p} = JSONStream.new()

  p =
    Enum.reduce(chunks, p, fn c, p ->
      {:ok, _events, p} = JSONStream.feed(p, c)
      p
    end)

  {:ok, _} = JSONStream.finish(p)
end

naive_parse = fn chunks ->
  Enum.reduce(chunks, "", fn c, buf ->
    buf = buf <> c
    _ = Formata.decode(buf, :json)
    buf
  end)
end

measure = fn fun ->
  times =
    for _ <- 1..5 do
      task =
        Task.async(fn ->
          :erlang.garbage_collect()
          {t, _} = :timer.tc(fun)
          {:reductions, r} = :erlang.process_info(self(), :reductions)
          {t, r}
        end)

      Task.await(task, :infinity)
    end

  {ts, rs} = Enum.unzip(times)
  {Enum.at(Enum.sort(ts), 2), Enum.at(Enum.sort(rs), 2)}
end

row = fn label, n_chunks, {us, red} ->
  IO.puts(
    String.pad_trailing(label, 34) <>
      String.pad_leading("#{n_chunks}", 9) <>
      String.pad_leading(:erlang.float_to_binary(us / 1000, decimals: 2), 12) <>
      String.pad_leading("#{red}", 14)
  )
end

big = doc.(2_000)
IO.puts("document: #{byte_size(big)} bytes\n")
IO.puts(String.pad_trailing("parser", 34) <> String.pad_leading("chunks", 9) <> String.pad_leading("ms", 12) <> String.pad_leading("reductions", 14))
row.("Formata.decode/3 (one shot)", 1, measure.(fn -> Formata.decode(big, :json) end))

for size <- [byte_size(big), 65_536, 4096, 256, 16, 1] do
  cs = chunks.(big, size)
  row.("Stream, #{size}-byte chunks", length(cs), measure.(fn -> stream_parse.(cs) end))
end

small = doc.(100)
IO.puts("\ndocument: #{byte_size(small)} bytes (naive comparison)\n")

for size <- [4096, 256, 16] do
  cs = chunks.(small, size)
  row.("Stream, #{size}-byte chunks", length(cs), measure.(fn -> stream_parse.(cs) end))
  row.("Re-decode buffer, #{size}-byte", length(cs), measure.(fn -> naive_parse.(cs) end))
end
