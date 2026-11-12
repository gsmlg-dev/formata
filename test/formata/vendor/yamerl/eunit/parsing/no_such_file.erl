-module(formata_yamerl_SUITE_parsing_no_such_file).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/no_such_file.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception,
        [
          {formata_yamerl_parsing_error,error,
            _,
            undefined,undefined,file_open_failure,undefined,[{error,enoent}]}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
