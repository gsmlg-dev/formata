-module(formata_yaml_SUITE_parsing_enc_invalid_unicode).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/enc_invalid_unicode.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception, [
          {formata_yaml_parsing_error,error,
            "Invalid Unicode character at byte #4",
            undefined,undefined,invalid_unicode,undefined,
            [{byte,4}]}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
