-module(formata_yamerl_SUITE_construction_size).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/size.yaml").

%% Formata fork: upstream set these node modules through the removed yamerl
%% application environment (yamerl_app:set_param/2); they are passed per call.
-define(NODE_MODS, [formata_yamerl_node_size]).

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              2000, 2000000, 2000000000, 2000000000000,
              2048, 2097152, 2147483648, 2199023255552,
              "Not a size"
            ]
          ],
          formata_yamerl_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, false}])
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
                [{formata_yamerl_int,formata_yamerl_node_size,"tag:yamerl,2012:size",
                    [{line,1},{column,3}],
                    2000},
                  {formata_yamerl_int,formata_yamerl_node_size,"tag:yamerl,2012:size",
                    [{line,2},{column,3}],
                    2000000},
                  {formata_yamerl_int,formata_yamerl_node_size,"tag:yamerl,2012:size",
                    [{line,3},{column,3}],
                    2000000000},
                  {formata_yamerl_int,formata_yamerl_node_size,"tag:yamerl,2012:size",
                    [{line,4},{column,3}],
                    2000000000000},
                  {formata_yamerl_int,formata_yamerl_node_size,"tag:yamerl,2012:size",
                    [{line,6},{column,3}],
                    2048},
                  {formata_yamerl_int,formata_yamerl_node_size,"tag:yamerl,2012:size",
                    [{line,7},{column,3}],
                    2097152},
                  {formata_yamerl_int,formata_yamerl_node_size,"tag:yamerl,2012:size",
                    [{line,8},{column,3}],
                    2147483648},
                  {formata_yamerl_int,formata_yamerl_node_size,"tag:yamerl,2012:size",
                    [{line,9},{column,3}],
                    2199023255552},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,11},{column,3}],
                    "Not a size"}],
                9}}
          ],
          formata_yamerl_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, true}])
        )
      ]
    }.
