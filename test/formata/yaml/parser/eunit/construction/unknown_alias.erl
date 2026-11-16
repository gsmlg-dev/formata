-module(formata_yaml_SUITE_construction_unknown_alias).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/unknown_alias.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yaml_exception,
            [{formata_yaml_parsing_error,error,
                "No anchor corresponds to alias \"anchor\"",
                2,3,no_matching_anchor,
                {formata_yaml_alias,2,3,"anchor"},
                []}
            ]
          },
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, false}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yaml_exception,
            [{formata_yaml_parsing_error,error,
                "No anchor corresponds to alias \"anchor\"",
                2,3,no_matching_anchor,
                {formata_yaml_alias,2,3,"anchor"},
                []}
            ]
          },
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, true}])
        )
      ]
    }.
