-module(formata_yamerl_SUITE_construction_null_json).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/null_json.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [null]
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
                [{formata_yamerl_null,formata_yamerl_node_null_json,
                    "tag:yaml.org,2002:null",
                    [{line,1},{column,3}]}],
                1}}
          ],
          formata_yamerl_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, json}])
        )
      ]
    }.
