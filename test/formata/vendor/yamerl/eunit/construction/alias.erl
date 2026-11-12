-module(formata_yamerl_SUITE_construction_alias).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/alias.yaml").

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
          formata_yamerl_constr:file(?FILENAME, [{detailed_constr, false}])
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
              {formata_yamerl_seq,formata_yamerl_node_seq, "tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,1},{column,11}],
                    "Duplicate"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,1},{column,11}],
                    "Duplicate"}
                ],
                2}
            }
          ],
          formata_yamerl_constr:file(?FILENAME, [{detailed_constr, true}])
        )
      ]
    }.
