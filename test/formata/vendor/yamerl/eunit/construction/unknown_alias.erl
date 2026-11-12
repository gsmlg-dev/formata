-module(formata_yamerl_SUITE_construction_unknown_alias).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/unknown_alias.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yamerl_exception,
            [{formata_yamerl_parsing_error,error,
                "No anchor corresponds to alias \"anchor\"",
                2,3,no_matching_anchor,
                {formata_yamerl_alias,2,3,"anchor"},
                []}
            ]
          },
          formata_yamerl_constr:file(?FILENAME, [{detailed_constr, false}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yamerl_exception,
            [{formata_yamerl_parsing_error,error,
                "No anchor corresponds to alias \"anchor\"",
                2,3,no_matching_anchor,
                {formata_yamerl_alias,2,3,"anchor"},
                []}
            ]
          },
          formata_yamerl_constr:file(?FILENAME, [{detailed_constr, true}])
        )
      ]
    }.
