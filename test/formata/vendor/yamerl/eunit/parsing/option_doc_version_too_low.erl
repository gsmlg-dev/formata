-module(formata_yamerl_SUITE_parsing_option_doc_version_too_low).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/option_doc_version_too_low.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception,
        [
          {formata_yamerl_parsing_error,error,
            "Version 0.9 not supported (minimum version 1.1)",
            1,1,version_not_supported,
            {formata_yamerl_doc_start,1,1,{0,9},_},
            []}
        ]
      },
      formata_yamerl_parser:file(?FILENAME, [{doc_version, {0,9}}])
    ).
