-module('formata_yaml_SUITE_parsing_ex_8.3_invalid_block_scalar_indentation_indicators_2').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_8.3_invalid_block_scalar_indentation_indicators_2.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_parsing_error,error,
            "Invalid block scalar indentation",
            3,2,invalid_block_scalar_indentation,
            {formata_yaml_scalar,1,3,{formata_yaml_tag,1,3,{non_specific,"!"}},block,folded,"text"},
            []}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
