-module(formata_yamerl_SUITE_wrapper_decode).

-include_lib("eunit/include/eunit.hrl").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertEqual(
          formata_yamerl:decode("[one, two]"),
          formata_yamerl_constr:string("[one, two]")
        )
      ]
    }.

explicit_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertEqual(
          formata_yamerl:decode("[one, two]", [{detailed_constr, false}]),
          formata_yamerl_constr:string("[one, two]", [{detailed_constr, false}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertEqual(
          formata_yamerl:decode("[one, two]", [{detailed_constr, true}]),
          formata_yamerl_constr:string("[one, two]", [{detailed_constr, true}])
        )
      ]
    }.
