-module('formata_yamerl_SUITE_parsing_ex_6.27_invalid_tag_shorthands').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_6.27_invalid_tag_shorthands.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception,
        [
          {formata_yamerl_parsing_error,error,
            "Tag handle \"!h!\" never declared",
            4,9,undeclared_tag_handle,{formata_yamerl_tag,4,3,"!h!bar"},
            []},
          {formata_yamerl_parsing_error,error,
            "Tag suffix mandatory",
            3,6,invalid_tag_handle,{formata_yamerl_tag,3,3,"!e!"},
            []}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
