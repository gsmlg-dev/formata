defmodule Formata.JSON.Decoder do
  @moduledoc false

  alias Formata.Error

  def decode(input, opts) do
    decoder_opts = [
      objects: :ordered_objects,
      floats: Keyword.get(opts, :floats, :native),
      comments: Keyword.get(opts, :comments, false),
      trailing_commas: Keyword.get(opts, :trailing_commas, false)
    ]

    case Formata.JSON.Backend.decode(input, decoder_opts) do
      {:ok, value} ->
        case unorder(value, [], Keyword.get(opts, :objects, :maps)) do
          {:ok, data} -> {:ok, data}
          {:error, error} -> {:error, [error]}
        end

      {:error, %Formata.JSON.Backend.DecodeError{position: position} = error} ->
        Error.error(:parse, :syntax, Exception.message(error),
          backend: Formata.JSON.Backend,
          format: :json,
          location: Formata.Codec.offset_location(input, position),
          cause: error
        )
    end
  end

  defp unorder(%Formata.JSON.OrderedObject{values: pairs}, path, objects) do
    Enum.reduce_while(pairs, {:ok, %{}, []}, fn {key, value}, {:ok, acc, ordered} ->
      if Map.has_key?(acc, key) do
        {:halt,
         {:error,
          Error.new(:parse, :duplicate_key, "duplicate object key #{inspect(key)}",
            backend: Formata.JSON.Backend,
            format: :json,
            path: Enum.reverse(path),
            details: %{key: key}
          )}}
      else
        case unorder(value, [key | path], objects) do
          {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value), [{key, value} | ordered]}}
          error -> {:halt, error}
        end
      end
    end)
    |> case do
      {:ok, map, _pairs} when objects == :maps -> {:ok, map}
      {:ok, _map, pairs} -> {:ok, Formata.JSON.OrderedObject.new(Enum.reverse(pairs))}
      error -> error
    end
  end

  defp unorder(list, path, objects) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {item, i}, {:ok, acc} ->
      case unorder(item, [i | path], objects) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp unorder(value, _path, _objects), do: {:ok, value}
end
