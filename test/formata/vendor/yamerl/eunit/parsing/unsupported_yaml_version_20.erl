-module(formata_yamerl_SUITE_parsing_unsupported_yaml_version_20).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/unsupported_yaml_version_20.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception,
        [
          {formata_yamerl_parsing_error,error,
            "Version 2.0 not supported (maximum version 1.2)",
            2,1,version_not_supported,
            {formata_yamerl_doc_start,2,1,{2,0},_},
            []}
        ]
      },
      formata_yamerl_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
