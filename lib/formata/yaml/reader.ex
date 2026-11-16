defmodule Formata.YAML.Reader do
  alias Formata.YAML.Reader.Mapper

  @parser_options [
    detailed_constr: true,
    str_node_as_binary: true,
    keep_duplicate_keys: true,
    preserve_scalar_metadata: true
  ]

  @doc false
  # Retain the detailed tree for validation before Mapper can discard entries.
  def read_nodes_from_string(string, options \\ []) do
    {:ok, :formata_yaml_constr.string(string, merge_options(options))}
  catch
    {:formata_yaml_exception, [error | _]} ->
      {:error, Formata.YAML.Reader.ParsingError.from_parser(error)}

    {:formata_yaml_parsing_error, _, _, _, _, _, _, _} = error ->
      {:error, Formata.YAML.Reader.ParsingError.from_parser(error)}
  end

  def read_all_from_file!(path, options \\ []) do
    case read_all_from_file(path, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def read_all_from_file(path, options \\ []), do: do_read(:file, path, options)

  def read_from_file!(path, options \\ []) do
    case read_from_file(path, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def read_from_file(path, options \\ []),
    do: do_read(:file, path, Keyword.put(options, :one_result, true))

  def read_all_from_string!(string, options \\ []) do
    case read_all_from_string(string, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def read_all_from_string(string, options \\ []), do: do_read(:string, string, options)

  def read_from_string!(string, options \\ []) do
    case read_from_string(string, options) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def read_from_string(string, options \\ []),
    do: do_read(:string, string, Keyword.put(options, :one_result, true))

  defp do_read(type, source, options) do
    {:ok, prepare_and_read(type, source, options)}
  catch
    {:formata_yaml_exception, [{_, _, message, _, _, :file_open_failure, _, _}]} ->
      {:error, %Formata.YAML.Reader.FileNotFoundError{message: List.to_string(message)}}

    {:formata_yaml_exception, [error | _]} ->
      {:error, Formata.YAML.Reader.ParsingError.from_parser(error)}

    _, _ ->
      {:error, %Formata.YAML.Reader.ParsingError{message: "malformed yaml"}}
  end

  defp prepare_and_read(type, source, options) do
    options
    |> merge_options()
    |> read(type, source)
  end

  defp read(options, type, source) do
    type
    |> construct(source, options)
    |> extract_data(options)
    |> Mapper.process(options)
  end

  defp merge_options(options), do: Keyword.merge(options, @parser_options)

  defp construct(:file, path, options), do: :formata_yaml_constr.file(path, options)
  defp construct(:string, data, options), do: :formata_yaml_constr.string(data, options)

  defp extract_data(data, options) do
    options
    |> Keyword.get(:one_result)
    |> maybe_take_last(data)
  end

  defp maybe_take_last(true, data), do: List.last(data)
  defp maybe_take_last(_, data), do: data
end
