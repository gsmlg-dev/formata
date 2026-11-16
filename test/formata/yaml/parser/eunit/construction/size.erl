-module(formata_yaml_SUITE_construction_size).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/size.yaml").

%% Formata fork: upstream set these node modules through the removed yamerl
%% application environment (yamerl_app:set_param/2); they are passed per call.
-define(NODE_MODS, [formata_yaml_node_size]).

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
          formata_yaml_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, false}])
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
                [{formata_yaml_int,formata_yaml_node_size,"tag:yamerl,2012:size",
                    [{line,1},{column,3}],
                    2000},
                  {formata_yaml_int,formata_yaml_node_size,"tag:yamerl,2012:size",
                    [{line,2},{column,3}],
                    2000000},
                  {formata_yaml_int,formata_yaml_node_size,"tag:yamerl,2012:size",
                    [{line,3},{column,3}],
                    2000000000},
                  {formata_yaml_int,formata_yaml_node_size,"tag:yamerl,2012:size",
                    [{line,4},{column,3}],
                    2000000000000},
                  {formata_yaml_int,formata_yaml_node_size,"tag:yamerl,2012:size",
                    [{line,6},{column,3}],
                    2048},
                  {formata_yaml_int,formata_yaml_node_size,"tag:yamerl,2012:size",
                    [{line,7},{column,3}],
                    2097152},
                  {formata_yaml_int,formata_yaml_node_size,"tag:yamerl,2012:size",
                    [{line,8},{column,3}],
                    2147483648},
                  {formata_yaml_int,formata_yaml_node_size,"tag:yamerl,2012:size",
                    [{line,9},{column,3}],
                    2199023255552},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,11},{column,3}],
                    "Not a size"}],
                9}}
          ],
          formata_yaml_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, true}])
        )
      ]
    }.
