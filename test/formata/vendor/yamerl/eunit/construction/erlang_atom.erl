-module(formata_yamerl_SUITE_construction_erlang_atom).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/erlang_atom.yaml").

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
            [
              atom,
              'atom requiring quoting!',
              "atom",
              "node@domain",
              "not an atom",
              "NotAnAtom",
              "Not an atom",
              "Not an atom"
            ]
          ],
          formata_yamerl_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, false}])
        )
      ]
    }.

autodetection_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              atom,
              'atom requiring quoting!',
              atom,
              node@domain,
              "not an atom",
              "NotAnAtom",
              "Not an atom",
              "Not an atom"
            ]
          ],
          formata_yamerl_constr:file(?FILENAME, [
              {node_mods, ?NODE_MODS},
              {detailed_constr, false},
              {erlang_atom_autodetection, true}
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
              {formata_yamerl_seq,formata_yamerl_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [
                  {formata_yamerl_erlang_atom,formata_yamerl_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,1},{column,27}],
                    atom},
                  {formata_yamerl_erlang_atom,formata_yamerl_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,2},{column,27}],
                    'atom requiring quoting!'},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,4},{column,3}],
                    "atom"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,5},{column,3}],
                    "node@domain"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "not an atom"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,8},{column,3}],
                    "NotAnAtom"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,9},{column,3}],
                    "Not an atom"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,10},{column,3}],
                    "Not an atom"}],
                8}}
          ],
          formata_yamerl_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, true}])
        )
      ]
    }.

autodetection_detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yamerl_doc,
              {formata_yamerl_seq,formata_yamerl_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [
                  {formata_yamerl_erlang_atom,formata_yamerl_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,1},{column,27}],
                    atom},
                  {formata_yamerl_erlang_atom,formata_yamerl_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,2},{column,27}],
                    'atom requiring quoting!'},
                  {formata_yamerl_erlang_atom,formata_yamerl_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,4},{column,3}],
                    atom},
                  {formata_yamerl_erlang_atom,formata_yamerl_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,5},{column,3}],
                    node@domain},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "not an atom"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,8},{column,3}],
                    "NotAnAtom"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,9},{column,3}],
                    "Not an atom"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,10},{column,3}],
                    "Not an atom"}],
                8}}
          ],
          formata_yamerl_constr:file(?FILENAME, [
              {node_mods, ?NODE_MODS},
              {detailed_constr, true},
              {erlang_atom_autodetection, true}
            ])
        )
      ]
    }.
