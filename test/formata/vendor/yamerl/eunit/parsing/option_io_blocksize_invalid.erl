-module(formata_yamerl_SUITE_parsing_option_io_blocksize_invalid).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/option_io_blocksize_invalid.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception, [
          {formata_yamerl_invalid_option,error,
            "Invalid value for option \"io_blocksize\": it must be a positive integer, expressed in bytes",
            {io_blocksize,invalid}}
        ]
      },
      formata_yamerl_parser:file(?FILENAME, [{io_blocksize, invalid}])
    ).
