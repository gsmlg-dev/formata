-module(formata_yaml_SUITE_construction_bool_json).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/bool_json.yaml").

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
                [{formata_yaml_bool,formata_yaml_node_bool_json,
                    "tag:yaml.org,2002:bool",
                    [{line,1},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_json,
                    "tag:yaml.org,2002:bool",
                    [{line,2},{column,3}],
                    false}],
                2}
            }
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, json}])
        )
      ]
    }.
