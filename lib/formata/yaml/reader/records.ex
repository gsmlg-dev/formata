defmodule Formata.YAML.Reader.Records do
  require Record

  Record.defrecord(
    :formata_yaml_constr,
    Record.extract(:formata_yaml_constr,
      from: Path.expand("../../../../include/internal/formata_yaml_constr.hrl", __DIR__)
    )
  )

  # Unable to extract here since the record defined in Erlang uses an Erlang macro
  # which breaks the extraction.
  Record.defrecord(
    :unfinished_node,
    module: nil,
    path: nil,
    pres: nil,
    priv: nil
  )

  Record.defrecord(
    :formata_yaml_map,
    Record.extract(:formata_yaml_map,
      from: Path.expand("../../../../include/formata_yaml_nodes.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yaml_collection_start,
    Record.extract(:formata_yaml_collection_start,
      from: Path.expand("../../../../include/formata_yaml_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yaml_collection_end,
    Record.extract(:formata_yaml_collection_end,
      from: Path.expand("../../../../include/formata_yaml_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yaml_mapping_key,
    Record.extract(:formata_yaml_mapping_key,
      from: Path.expand("../../../../include/formata_yaml_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yaml_mapping_value,
    Record.extract(:formata_yaml_mapping_value,
      from: Path.expand("../../../../include/formata_yaml_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yaml_tag,
    Record.extract(:formata_yaml_tag,
      from: Path.expand("../../../../include/formata_yaml_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yaml_parsing_error,
    Record.extract(:formata_yaml_parsing_error,
      from: Path.expand("../../../../include/formata_yaml_errors.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yaml_keyword_list,
    module: __MODULE__,
    tag: "tag:yaml_elixir,2019:keyword_list",
    pres: [],
    pairs: []
  )
end
