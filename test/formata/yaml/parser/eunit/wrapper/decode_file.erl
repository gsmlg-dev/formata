-module(formata_yaml_SUITE_wrapper_decode_file).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/wrapper/decode_file.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertEqual(
          formata_yaml:decode_file(?FILENAME),
          formata_yaml_constr:file(?FILENAME)
        )
      ]
    }.

explicit_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertEqual(
          formata_yaml:decode_file(?FILENAME, [{detailed_constr, false}]),
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, false}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertEqual(
          formata_yaml:decode_file(?FILENAME, [{detailed_constr, true}]),
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, true}])
        )
      ]
    }.
