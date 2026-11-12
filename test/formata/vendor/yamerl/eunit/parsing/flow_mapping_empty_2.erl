-module(formata_yamerl_SUITE_parsing_flow_mapping_empty_2).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/flow_mapping_empty_2.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception,
        [
          {formata_yamerl_parsing_error,error,
            "Empty flow collection entry not allowed",
            2,1,flow_collection_entry_not_allowed,undefined,[]}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
