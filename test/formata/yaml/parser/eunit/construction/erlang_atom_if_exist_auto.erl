-module(formata_yaml_SUITE_construction_erlang_atom_if_exist_auto).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/erlang_atom_if_exist_auto.yaml").

%% Formata fork: upstream set these node modules through the removed yamerl
%% application environment (yamerl_app:set_param/2); they are passed per call.
-define(NODE_MODS, [formata_yaml_node_erlang_atom]).

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            "inexistent_atom"
          ],
          formata_yaml_constr:file(?FILENAME, [
              {node_mods, ?NODE_MODS},
              {detailed_constr, false},
              {erlang_atom_autodetection, true},
              {erlang_atom_only_if_exist, true}
            ])
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
              {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                [{line,1},{column,1}],
                "inexistent_atom"}
            }
          ],
          formata_yaml_constr:file(?FILENAME, [
              {node_mods, ?NODE_MODS},
              {detailed_constr, true},
              {erlang_atom_autodetection, true},
              {erlang_atom_only_if_exist, true}
            ])
        )
      ]
    }.
