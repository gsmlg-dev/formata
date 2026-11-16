-module(formata_yaml_SUITE_parsing_option_doc_version_too_low).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/option_doc_version_too_low.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_parsing_error,error,
            "Version 0.9 not supported (minimum version 1.1)",
            1,1,version_not_supported,
            {formata_yaml_doc_start,1,1,{0,9},_},
            []}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{doc_version, {0,9}}])
    ).
