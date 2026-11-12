defmodule Formata.YamlElixir.Records do
  require Record

  Record.defrecord(
    :formata_yamerl_constr,
    Record.extract(:formata_yamerl_constr,
      from: Path.expand("../../../include/internal/formata_yamerl_constr.hrl", __DIR__)
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
    :formata_yamerl_map,
    Record.extract(:formata_yamerl_map,
      from: Path.expand("../../../include/formata_yamerl_nodes.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yamerl_collection_start,
    Record.extract(:formata_yamerl_collection_start,
      from: Path.expand("../../../include/formata_yamerl_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yamerl_collection_end,
    Record.extract(:formata_yamerl_collection_end,
      from: Path.expand("../../../include/formata_yamerl_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yamerl_mapping_key,
    Record.extract(:formata_yamerl_mapping_key,
      from: Path.expand("../../../include/formata_yamerl_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yamerl_mapping_value,
    Record.extract(:formata_yamerl_mapping_value,
      from: Path.expand("../../../include/formata_yamerl_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yamerl_tag,
    Record.extract(:formata_yamerl_tag,
      from: Path.expand("../../../include/formata_yamerl_tokens.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :formata_yamerl_parsing_error,
    Record.extract(:formata_yamerl_parsing_error,
      from: Path.expand("../../../include/formata_yamerl_errors.hrl", __DIR__)
    )
  )

  Record.defrecord(
    :yaml_elixir_keyword_list,
    module: __MODULE__,
    tag: "tag:yaml_elixir,2019:keyword_list",
    pres: [],
    pairs: []
  )
end
