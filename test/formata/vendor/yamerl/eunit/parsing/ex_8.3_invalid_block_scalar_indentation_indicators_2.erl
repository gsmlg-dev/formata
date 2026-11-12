-module('formata_yamerl_SUITE_parsing_ex_8.3_invalid_block_scalar_indentation_indicators_2').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_8.3_invalid_block_scalar_indentation_indicators_2.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception,
        [
          {formata_yamerl_parsing_error,error,
            "Invalid block scalar indentation",
            3,2,invalid_block_scalar_indentation,
            {formata_yamerl_scalar,1,3,{formata_yamerl_tag,1,3,{non_specific,"!"}},block,folded,"text"},
            []}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
