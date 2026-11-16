-module(formata_yaml_SUITE_parsing_flow_mapping_no_entry_1).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/flow_mapping_no_entry_1.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_parsing_error,error,
            "Unexpected \"formata_yaml_scalar\" token following a \"formata_yaml_scalar\" token",
            3,1,unexpected_token,
            {formata_yaml_scalar,3,1,
              {formata_yaml_tag,3,1,{non_specific,"!"}},
              flow,double_quoted,"item2"},
            []}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
