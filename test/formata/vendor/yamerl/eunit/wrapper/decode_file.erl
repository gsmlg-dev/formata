-module(formata_yamerl_SUITE_wrapper_decode_file).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/wrapper/decode_file.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertEqual(
          formata_yamerl:decode_file(?FILENAME),
          formata_yamerl_constr:file(?FILENAME)
        )
      ]
    }.

explicit_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertEqual(
          formata_yamerl:decode_file(?FILENAME, [{detailed_constr, false}]),
          formata_yamerl_constr:file(?FILENAME, [{detailed_constr, false}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertEqual(
          formata_yamerl:decode_file(?FILENAME, [{detailed_constr, true}]),
          formata_yamerl_constr:file(?FILENAME, [{detailed_constr, true}])
        )
      ]
    }.
