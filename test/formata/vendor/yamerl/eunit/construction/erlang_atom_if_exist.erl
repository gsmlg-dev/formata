-module(formata_yamerl_SUITE_construction_erlang_atom_if_exist).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/erlang_atom_if_exist.yaml").

%% Formata fork: upstream set these node modules through the removed yamerl
%% application environment (yamerl_app:set_param/2); they are passed per call.
-define(NODE_MODS, [formata_yamerl_node_erlang_atom]).

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yamerl_exception,
            [{formata_yamerl_parsing_error, error,
                "Non-existing Erlang atom",
                1, 27,
                non_existing_erlang_atom,
                {formata_yamerl_scalar, 1, 27,
                  {formata_yamerl_tag, 1, 3, "tag:yamerl,2012:atom"},
                  flow, plain, "inexistent_atom"
                },
                []
              }]
          },
          formata_yamerl_constr:file(?FILENAME, [
              {node_mods, ?NODE_MODS},
              {detailed_constr, false},
              {erlang_atom_only_if_exist, true}
            ])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yamerl_exception,
            [{formata_yamerl_parsing_error, error,
                "Non-existing Erlang atom",
                1, 27,
                non_existing_erlang_atom,
                {formata_yamerl_scalar, 1, 27,
                  {formata_yamerl_tag, 1, 3, "tag:yamerl,2012:atom"},
                  flow, plain, "inexistent_atom"
                },
                []
              }]
          },
          formata_yamerl_constr:file(?FILENAME, [
              {node_mods, ?NODE_MODS},
              {detailed_constr, true},
              {erlang_atom_only_if_exist, true}
            ])
        )
      ]
    }.
