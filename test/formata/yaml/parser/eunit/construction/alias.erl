-module(formata_yaml_SUITE_construction_alias).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/alias.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              "Duplicate",
              "Duplicate"
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
              {formata_yaml_seq,formata_yaml_node_seq, "tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,1},{column,11}],
                    "Duplicate"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,1},{column,11}],
                    "Duplicate"}
                ],
                2}
            }
          ],
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, true}])
        )
      ]
    }.
