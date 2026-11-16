-module(formata_yaml_SUITE_parsing_no_such_file).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/no_such_file.yaml").

single_test_() ->
    ?_assertThrow(
      {formata_yaml_exception,
        [
          {formata_yaml_parsing_error,error,
            _,
            undefined,undefined,file_open_failure,undefined,[{error,enoent}]}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
