-module(formata_yaml_SUITE_construction_seq).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/seq.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              [ "item", 1 ],
              [ "item", 2 ]
            ]
          ],
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, false}])
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
                [{formata_yaml_seq,formata_yaml_node_seq,"tag:yaml.org,2002:seq",
                    [{line,1},{column,3}],
                    [{formata_yaml_str,formata_yaml_node_str,
                        "tag:yaml.org,2002:str",
                        [{line,1},{column,5}],
                        "item"},
                      {formata_yaml_int,formata_yaml_node_int,
                        "tag:yaml.org,2002:int",
                        [{line,1},{column,11}],
                        1}],
                    2},
                  {formata_yaml_seq,formata_yaml_node_seq,"tag:yaml.org,2002:seq",
                    [{line,2},{column,3}],
                    [{formata_yaml_str,formata_yaml_node_str,
                        "tag:yaml.org,2002:str",
                        [{line,2},{column,5}],
                        "item"},
                      {formata_yaml_int,formata_yaml_node_int,
                        "tag:yaml.org,2002:int",
                        [{line,2},{column,11}],
                        2}],
                    2}],
                2}
            }
          ],
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, true}])
        )
      ]
    }.
