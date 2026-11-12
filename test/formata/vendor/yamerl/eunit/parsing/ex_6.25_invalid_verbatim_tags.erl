-module('formata_yamerl_SUITE_parsing_ex_6.25_invalid_verbatim_tags').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_6.25_invalid_verbatim_tags.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception,
        [
          {formata_yamerl_parsing_error,warning,
            "Invalid character in URI scheme",
            2,3,invalid_uri,{formata_yamerl_tag,2,3,"$:?"},
            []},
          {formata_yamerl_parsing_error,error,
            "Local tag suffix mandatory",
            1,7,invalid_tag_handle,
            {formata_yamerl_tag,1,3,"!"},
            []}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
