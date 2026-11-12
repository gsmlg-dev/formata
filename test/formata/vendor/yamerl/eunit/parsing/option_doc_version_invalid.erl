-module(formata_yamerl_SUITE_parsing_option_doc_version_invalid).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/option_doc_version_invalid.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception,
        [
          {formata_yamerl_invalid_option,error,
            "Invalid value for option \"doc_version\": it must be a tuple of the form {Major, Minor} where Major and Minor are positive integers",
            {doc_version,invalid}}
        ]
      },
      formata_yamerl_parser:file(?FILENAME, [{doc_version, invalid}])
    ).
