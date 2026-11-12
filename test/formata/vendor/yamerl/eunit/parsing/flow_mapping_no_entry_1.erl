-module(formata_yamerl_SUITE_parsing_flow_mapping_no_entry_1).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/flow_mapping_no_entry_1.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception,
        [
          {formata_yamerl_parsing_error,error,
            "Unexpected \"formata_yamerl_scalar\" token following a \"formata_yamerl_scalar\" token",
            3,1,unexpected_token,
            {formata_yamerl_scalar,3,1,
              {formata_yamerl_tag,3,1,{non_specific,"!"}},
              flow,double_quoted,"item2"},
            []}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
