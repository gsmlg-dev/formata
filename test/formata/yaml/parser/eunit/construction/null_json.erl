-module(formata_yaml_SUITE_construction_null_json).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/null_json.yaml").

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
          formata_yaml_constr:file(?FILENAME,
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
            {formata_yaml_doc,
              {formata_yaml_seq,formata_yaml_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [{formata_yaml_null,formata_yaml_node_null_json,
                    "tag:yaml.org,2002:null",
                    [{line,1},{column,3}]}],
                1}}
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, json}])
        )
      ]
    }.
