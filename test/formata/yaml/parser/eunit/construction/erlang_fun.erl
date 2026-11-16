-module(formata_yaml_SUITE_construction_erlang_fun).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/erlang_fun.yaml").

%% Formata fork: upstream set these node modules through the removed yamerl
%% application environment (yamerl_app:set_param/2); they are passed per call.
-define(NODE_MODS, [formata_yaml_node_erlang_fun]).

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        {generator,
          fun() ->
              [Erlang_Fun_Simple] = formata_yaml_constr:file(?FILENAME,
                [{node_mods, ?NODE_MODS},{detailed_constr, false}]),
              ?_assertMatch(
                "Hello World!",
                Erlang_Fun_Simple()
              )
          end}
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        {generator,
          fun() ->
              [{formata_yaml_doc,
                  {formata_yaml_erlang_fun,formata_yaml_node_erlang_fun,
                    "tag:yamerl,2012:fun",
                    [{line,1},{column,24}],
                    Erlang_Fun_Normal,
                    "fun() -> \"Hello World!\" end.\n"}}
              ] = formata_yaml_constr:file(?FILENAME,
                [{node_mods, ?NODE_MODS},{detailed_constr, true}]),
              ?_assertMatch(
                "Hello World!",
                Erlang_Fun_Normal()
              )
          end}
      ]
    }.
