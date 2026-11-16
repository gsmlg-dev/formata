-module(formata_yaml_SUITE_parsing_unsupported_yaml_version_20).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/unsupported_yaml_version_20.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_parsing_error,error,
            "Version 2.0 not supported (maximum version 1.2)",
            2,1,version_not_supported,
            {formata_yaml_doc_start,2,1,{2,0},_},
            []}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
