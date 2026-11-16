-module(formata_yaml_SUITE_parsing_option_doc_version_invalid).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/option_doc_version_invalid.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_invalid_option,error,
            "Invalid value for option \"doc_version\": it must be a tuple of the form {Major, Minor} where Major and Minor are positive integers",
            {doc_version,invalid}}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{doc_version, invalid}])
    ).
