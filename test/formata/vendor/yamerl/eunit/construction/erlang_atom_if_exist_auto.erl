-module(formata_yamerl_SUITE_construction_erlang_atom_if_exist_auto).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/erlang_atom_if_exist_auto.yaml").

%% Formata fork: upstream set these node modules through the removed yamerl
%% application environment (yamerl_app:set_param/2); they are passed per call.
-define(NODE_MODS, [formata_yamerl_node_erlang_atom]).

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
          formata_yamerl_constr:file(?FILENAME, [
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
            {formata_yamerl_doc,
              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                [{line,1},{column,1}],
                "inexistent_atom"}
            }
          ],
          formata_yamerl_constr:file(?FILENAME, [
              {node_mods, ?NODE_MODS},
              {detailed_constr, true},
              {erlang_atom_autodetection, true},
              {erlang_atom_only_if_exist, true}
            ])
        )
      ]
    }.
