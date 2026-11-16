defmodule Formata.YAML.Reader.Mapper do
  def process(nil, options), do: empty_container(options)
  def process(yaml, options) when is_list(yaml), do: Enum.map(yaml, &process(&1, options))

  def process(yaml, options) do
    yaml
    |> _to_map(options)
    |> extract_map(options)
    |> maybe_merge_anchors(options)
  end

  defp _to_map({:formata_yaml_doc, document}, options), do: _to_map(document, options)

  defp _to_map({:formata_yaml_seq, :formata_yaml_node_seq, _tag, _loc, seq, _n}, options),
    do: Enum.map(seq, &_to_map(&1, options))

  defp _to_map({:formata_yaml_map, :formata_yaml_node_map, _tag, _loc, map_tuples}, options),
    do: _tuples_to_map(map_tuples, empty_container(options), options)

  defp _to_map({:formata_yaml_keyword_list, _module, _tag, _loc, tuples}, options) do
    tuples
    |> _tuples_to_map(empty_container(options), options)
    |> to_keyword_list()
  end

  defp _to_map(
         {:formata_yaml_str, :formata_yaml_node_str, _tag, _loc, <<?:, _::binary>> = element},
         options
       ),
       do: key_for(element, options)

  defp _to_map({:formata_yaml_null, :formata_yaml_node_null, _tag, _loc}, _options), do: nil

  defp _to_map({:formata_yaml_null, :formata_yaml_node_null_json, _tag, _loc}, _options),
    do: nil

  defp _to_map({_yamler_element, _yamler_node_element, _tag, _loc, elem}, _options), do: elem

  defp to_keyword_list(map) when is_map(map) do
    for {key, value} <- map,
        do: {key, value}
  end

  defp to_keyword_list(keyword_list), do: keyword_list

  defp _tuples_to_map([], map, _options), do: map

  defp _tuples_to_map([{key, val} | rest], map, options) do
    agregator_module = maps_aggregator(options)

    _tuples_to_map(
      rest,
      agregator_module.(map, mapping_key(key, options), _to_map(val, options)),
      options
    )
  end

  defp mapping_key({:formata_yaml_str, _, _, pres, "<<"} = key, options) do
    if options[:merge_anchors] && pres[:scalar_style] == :plain &&
         pres[:source_tag] == {:non_specific, ~c"?"} do
      {:yaml_merge_key, make_ref()}
    else
      _to_map(key, options)
    end
  end

  defp mapping_key(key, options), do: _to_map(key, options)

  defp key_for(<<?:, name::binary>> = original_name, options) do
    options
    |> Keyword.get(:atoms)
    |> maybe_atom(name, original_name)
  end

  defp key_for(name, _options), do: name

  defp maybe_atom(true, name, _original_name), do: String.to_atom(name)
  defp maybe_atom(_, _name, original_name), do: original_name

  defp empty_container(options) do
    with true <- Keyword.get(options, :maps_as_keywords) do
      []
    else
      _ -> %{}
    end
  end

  defp extract_map(nil, options), do: empty_container(options)
  defp extract_map(map, _), do: map

  defp maps_aggregator(options) do
    with true <- Keyword.get(options, :maps_as_keywords) do
      &[{&2, &3} | &1]
    else
      _ -> &Map.put_new/3
    end
  end

  defp maybe_merge_anchors(value, options) do
    with true <- Keyword.get(options, :merge_anchors) do
      merge_anchors(value)
    else
      _ -> value
    end
  end

  defp merge_anchors(value) when is_list(value), do: Enum.map(value, &merge_anchors/1)

  defp merge_anchors(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn
      {{:yaml_merge_key, _}, v}, acc -> acc |> Map.merge(v)
      {k, v}, acc -> acc |> Map.put(k, merge_anchors(v))
    end)
  end

  defp merge_anchors(val), do: val
end
