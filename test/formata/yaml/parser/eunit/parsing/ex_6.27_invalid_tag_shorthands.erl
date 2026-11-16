-module('formata_yaml_SUITE_parsing_ex_6.27_invalid_tag_shorthands').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.27_invalid_tag_shorthands.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_parsing_error,error,
            "Tag handle \"!h!\" never declared",
            4,9,undeclared_tag_handle,{formata_yaml_tag,4,3,"!h!bar"},
            []},
          {formata_yaml_parsing_error,error,
            "Tag suffix mandatory",
            3,6,invalid_tag_handle,{formata_yaml_tag,3,3,"!e!"},
            []}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
