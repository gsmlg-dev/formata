-module(formata_yaml_SUITE_parsing_unfinished_flow_collection).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/unfinished_flow_collection.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception, [
          {formata_yaml_parsing_error,error,
            "Unfinished flow collection",
            1,6,unfinished_flow_collection,
            {formata_yaml_doc_end,1,6},
            []}]},
      formata_yaml_parser:file(?FILENAME)
    ).
