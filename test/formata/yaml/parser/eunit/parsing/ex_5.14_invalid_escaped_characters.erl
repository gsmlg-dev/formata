-module('formata_yaml_SUITE_parsing_ex_5.14_invalid_escaped_characters').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_5.14_invalid_escaped_characters.yaml").

% YAML escape productions are mandatory syntax, not recoverable warnings.
single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception, [
          {formata_yaml_parsing_error,error,
            "Invalid escaped character",
            3,3,invalid_escaped_character,
            {formata_yaml_scalar,2,3,{formata_yaml_tag,2,3,{non_specific,"!"}},flow,double_quoted,"c "},
            []},
          {formata_yaml_parsing_error,error,
            "Invalid escaped character",
            2,4,invalid_escaped_character,
            {formata_yaml_scalar,2,3,{formata_yaml_tag,2,3,{non_specific,"!"}},flow,double_quoted,""},
            []}
        ]},
      formata_yaml_parser:file(?FILENAME)
    ).
