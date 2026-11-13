-module('formata_yamerl_SUITE_parsing_ex_5.14_invalid_escaped_characters').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_5.14_invalid_escaped_characters.yaml").

% YAML escape productions are mandatory syntax, not recoverable warnings.
single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception, [
          {formata_yamerl_parsing_error,error,
            "Invalid escaped character",
            3,3,invalid_escaped_character,
            {formata_yamerl_scalar,2,3,{formata_yamerl_tag,2,3,{non_specific,"!"}},flow,double_quoted,"c "},
            []},
          {formata_yamerl_parsing_error,error,
            "Invalid escaped character",
            2,4,invalid_escaped_character,
            {formata_yamerl_scalar,2,3,{formata_yamerl_tag,2,3,{non_specific,"!"}},flow,double_quoted,""},
            []}
        ]},
      formata_yamerl_parser:file(?FILENAME)
    ).
