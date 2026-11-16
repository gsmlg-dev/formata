-module(formata_yaml_SUITE_construction_erlang_atom).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/erlang_atom.yaml").

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
          formata_yaml_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, false}])
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
          formata_yaml_constr:file(?FILENAME, [
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
            {formata_yaml_doc,
              {formata_yaml_seq,formata_yaml_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [
                  {formata_yaml_erlang_atom,formata_yaml_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,1},{column,27}],
                    atom},
                  {formata_yaml_erlang_atom,formata_yaml_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,2},{column,27}],
                    'atom requiring quoting!'},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,4},{column,3}],
                    "atom"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,5},{column,3}],
                    "node@domain"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "not an atom"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,8},{column,3}],
                    "NotAnAtom"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,9},{column,3}],
                    "Not an atom"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,10},{column,3}],
                    "Not an atom"}],
                8}}
          ],
          formata_yaml_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, true}])
        )
      ]
    }.

autodetection_detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yaml_doc,
              {formata_yaml_seq,formata_yaml_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [
                  {formata_yaml_erlang_atom,formata_yaml_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,1},{column,27}],
                    atom},
                  {formata_yaml_erlang_atom,formata_yaml_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,2},{column,27}],
                    'atom requiring quoting!'},
                  {formata_yaml_erlang_atom,formata_yaml_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,4},{column,3}],
                    atom},
                  {formata_yaml_erlang_atom,formata_yaml_node_erlang_atom,
                    "tag:yamerl,2012:atom",
                    [{line,5},{column,3}],
                    node@domain},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "not an atom"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,8},{column,3}],
                    "NotAnAtom"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,9},{column,3}],
                    "Not an atom"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,10},{column,3}],
                    "Not an atom"}],
                8}}
          ],
          formata_yaml_constr:file(?FILENAME, [
              {node_mods, ?NODE_MODS},
              {detailed_constr, true},
              {erlang_atom_autodetection, true}
            ])
        )
      ]
    }.
