-module(formata_yaml_SUITE_parsing_flow_mapping_empty_2).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/flow_mapping_empty_2.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_parsing_error,error,
            "Empty flow collection entry not allowed",
            2,1,flow_collection_entry_not_allowed,undefined,[]}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
