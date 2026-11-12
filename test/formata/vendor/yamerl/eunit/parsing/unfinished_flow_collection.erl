-module(formata_yamerl_SUITE_parsing_unfinished_flow_collection).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/unfinished_flow_collection.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception, [
          {formata_yamerl_parsing_error,error,
            "Unfinished flow collection",
            1,6,unfinished_flow_collection,
            {formata_yamerl_doc_end,1,6},
            []}]},
      formata_yamerl_parser:file(?FILENAME)
    ).
