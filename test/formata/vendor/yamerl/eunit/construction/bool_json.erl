-module(formata_yamerl_SUITE_construction_bool_json).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/bool_json.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              true,
              false
            ]
          ],
          formata_yamerl_constr:file(?FILENAME,
            [{detailed_constr, false}, {schema, json}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yamerl_doc,
              {formata_yamerl_seq,formata_yamerl_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [{formata_yamerl_bool,formata_yamerl_node_bool_json,
                    "tag:yaml.org,2002:bool",
                    [{line,1},{column,3}],
                    true},
                  {formata_yamerl_bool,formata_yamerl_node_bool_json,
                    "tag:yaml.org,2002:bool",
                    [{line,2},{column,3}],
                    false}],
                2}
            }
          ],
          formata_yamerl_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, json}])
        )
      ]
    }.
