-module(formata_yamerl_SUITE_parsing_enc_invalid_unicode).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/enc_invalid_unicode.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception, [
          {formata_yamerl_parsing_error,error,
            "Invalid Unicode character at byte #4",
            undefined,undefined,invalid_unicode,undefined,
            [{byte,4}]}
        ]
      },
      formata_yamerl_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
