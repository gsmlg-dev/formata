-module(formata_yaml_SUITE_parsing_option_io_blocksize_invalid).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/option_io_blocksize_invalid.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception, [
          {formata_yaml_invalid_option,error,
            "Invalid value for option \"io_blocksize\": it must be a positive integer, expressed in bytes",
            {io_blocksize,invalid}}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, invalid}])
    ).
