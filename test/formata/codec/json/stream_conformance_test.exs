defmodule Formata.Codec.JSON.StreamConformanceTest do
  # JSONTestSuite (https://github.com/nst/JSONTestSuite, MIT), vendored with
  # the Jason fork's tests (see test/fixtures/json/backend/PROVENANCE.md).
  #
  # For every y_ (must accept), n_ (must reject), and i_ (implementation
  # defined) case, the stream parser must agree with Formata.decode/3 on
  # acceptance and on the decoded value, whether the input arrives whole, byte
  # by byte, or split at random points. The only y_ cases Formata rejects are
  # duplicate keys, by design.
  use ExUnit.Case, async: true

  alias Formata.Codec.JSON.Stream, as: JSONStream

  @files Path.wildcard("test/fixtures/json/backend/json_test_suite/*.json")

  test "the suite is present" do
    assert length(@files) > 300
  end

  for path <- @files do
    name = Path.basename(path)

    test name do
      input = File.read!(unquote(path))
      expected = Formata.decode(input, :json)

      for {label, chunks} <- chunkings(input) do
        actual = parse(chunks)

        case {unquote(name), expected} do
          {"y_" <> _, {:ok, value}} ->
            assert {:ok, ^value} = actual, "#{label}: rejected a valid document"

          # Formata deliberately rejects duplicate keys, which the suite allows
          # (y_object_duplicated_key*); both parsers must reject them alike.
          {"y_object_duplicated_key" <> _, {:error, [%{code: :duplicate_key}]}} ->
            assert {:error, [%Formata.Error{code: :duplicate_key}]} = actual, "#{label}"

          {"y_" <> _, {:error, _}} ->
            flunk("Formata.decode/3 rejects a y_ case")

          {"n_" <> _, {:ok, _}} ->
            flunk("Formata.decode/3 accepts an n_ case")

          {_, {:ok, value}} ->
            assert {:ok, ^value} = actual, "#{label}: disagrees with Formata.decode/3"

          {_, {:error, _}} ->
            assert {:error, [%Formata.Error{kind: :parse}]} = actual,
                   "#{label}: accepted a document Formata.decode/3 rejects"
        end
      end
    end
  end

  defp chunkings(input) do
    :rand.seed(:exsss, {byte_size(input), 1, 2})
    random = random_chunks(input, [])
    bytes = for <<b::binary-1 <- input>>, do: b
    [whole: [input], bytes: bytes, random: random]
  end

  defp random_chunks(<<>>, acc), do: Enum.reverse(acc)

  defp random_chunks(input, acc) do
    n = min(:rand.uniform(9), byte_size(input))
    rest = binary_part(input, n, byte_size(input) - n)
    random_chunks(rest, [binary_part(input, 0, n) | acc])
  end

  # Feeds the chunks and rebuilds the value from the events.
  defp parse(chunks) do
    {:ok, parser} = JSONStream.new()

    result =
      Enum.reduce_while(chunks, {:ok, parser, []}, fn chunk, {:ok, parser, acc} ->
        case JSONStream.feed(parser, chunk) do
          {:ok, events, parser} -> {:cont, {:ok, parser, [acc | events]}}
          error -> {:halt, error}
        end
      end)

    with {:ok, parser, acc} <- result,
         {:ok, events} <- JSONStream.finish(parser) do
      {:ok, build(List.flatten([acc | events]))}
    end
  end

  defp build(events) do
    {[value], []} = Enum.reduce(events, {[], []}, &step/2)
    value
  end

  defp step({:start_object, _}, {values, stack}), do: {values, [{:object, []} | stack]}
  defp step({:start_array, _}, {values, stack}), do: {values, [{:array, []} | stack]}

  defp step({:key, _, key}, {values, [{:object, pairs} | stack]}),
    do: {values, [{:object, [key | pairs]} | stack]}

  defp step({:end_object, _}, {values, [{:object, pairs} | stack]}) do
    map =
      pairs |> Enum.reverse() |> Enum.chunk_every(2) |> Map.new(fn [k, v] -> {k, v} end)

    push(values, stack, map)
  end

  defp step({:end_array, _}, {values, [{:array, items} | stack]}),
    do: push(values, stack, Enum.reverse(items))

  defp step({:value, _, value}, {values, stack}), do: push(values, stack, value)

  defp push(values, [], value), do: {[value | values], []}

  defp push(values, [{:array, items} | stack], value),
    do: {values, [{:array, [value | items]} | stack]}

  defp push(values, [{:object, [key | pairs]} | stack], value),
    do: {values, [{:object, [value, key | pairs]} | stack]}
end
