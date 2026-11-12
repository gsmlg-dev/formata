-module(formata_yamerl_SUITE_construction_timestamp).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/timestamp.yaml").

%% Formata fork: upstream set these node modules through the removed yamerl
%% application environment (yamerl_app:set_param/2); they are passed per call.
-define(NODE_MODS, [formata_yamerl_node_timestamp]).

setup() ->
    ok.

teardown(_) ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      fun teardown/1,
      [
        ?_assertMatch(
          [
            [
              {{2011, 5, 26}, undefined},
              {undefined, {14,58,3}},
              {{2011, 5, 26}, {14,58,3}},
              {{2011, 5, 26}, {14,58,3}},
              {{2011, 5, 26}, {14,58,3}},
              "Not a timestamp"
            ]
          ],
          formata_yamerl_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, false}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      fun teardown/1,
      [
        ?_assertMatch(
          [
            {formata_yamerl_doc,
              {formata_yamerl_seq,formata_yamerl_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [{formata_yamerl_timestamp,formata_yamerl_node_timestamp,
                    "tag:yamerl,2012:timestamp",
                    [{line,1},{column,3}],
                    2011,5,26,undefined,undefined,undefined,
                    0,0},
                  {formata_yamerl_timestamp,formata_yamerl_node_timestamp,
                    "tag:yamerl,2012:timestamp",
                    [{line,2},{column,3}],
                    undefined,undefined,undefined,14,58,3,
                    0,0},
                  {formata_yamerl_timestamp,formata_yamerl_node_timestamp,
                    "tag:yamerl,2012:timestamp",
                    [{line,3},{column,3}],
                    2011,5,26,14,58,3,
                    0,0},
                  {formata_yamerl_timestamp,formata_yamerl_node_timestamp,
                    "tag:yamerl,2012:timestamp",
                    [{line,4},{column,3}],
                    2011,5,26,14,58,3,
                    0,0},
                  {formata_yamerl_timestamp,formata_yamerl_node_timestamp,
                    "tag:yamerl,2012:timestamp",
                    [{line,5},{column,3}],
                    2011,5,26,14,58,3,
                    0,0},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "Not a timestamp"}],
                6}}
          ],
          formata_yamerl_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, true}])
        )
      ]
    }.
