-module('formata_yaml_SUITE_parsing_ex_6.25_invalid_verbatim_tags').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.25_invalid_verbatim_tags.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_parsing_error,warning,
            "Invalid character in URI scheme",
            2,3,invalid_uri,{formata_yaml_tag,2,3,"$:?"},
            []},
          {formata_yaml_parsing_error,error,
            "Local tag suffix mandatory",
            1,7,invalid_tag_handle,
            {formata_yaml_tag,1,3,"!"},
            []}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
