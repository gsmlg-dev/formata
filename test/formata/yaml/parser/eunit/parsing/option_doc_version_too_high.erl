-module(formata_yaml_SUITE_parsing_option_doc_version_too_high).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/option_doc_version_too_high.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_parsing_error,error,
            "Version 2.0 not supported (maximum version 1.2)",
            1,1,version_not_supported,
            {formata_yaml_doc_start,1,1,{2,0},_},
            []}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{doc_version, {2,0}}])
    ).
