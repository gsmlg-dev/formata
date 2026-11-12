-module(formata_yamerl_SUITE_construction_ipaddr).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/ipaddr.yaml").

%% Formata fork: upstream set these node modules through the removed yamerl
%% application environment (yamerl_app:set_param/2); they are passed per call.
-define(NODE_MODS, [formata_yamerl_node_ipaddr]).

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              {192, 168, 1, 10},
              {{192, 168, 1, 10}, 24},
              {{192, 168, 1, 10}, {192, 168, 1, 20}},
              {8193,16848,1,28696,0,0,1,2},
              {{8193,16848,1,28696,0,0,1,0},64},
              {{8193,16848,1,28696,0,0,1,2},{8193,16848,1,28696,0,0,1,5}},
              "Not an IP address"
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
                [{formata_yamerl_ip_addr,formata_yamerl_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,1},{column,3}],
                    {192,168,1,10}},
                  {formata_yamerl_ip_netmask,formata_yamerl_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,2},{column,3}],
                    {192,168,1,10},
                    24},
                  {formata_yamerl_ip_range,formata_yamerl_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,3},{column,3}],
                    {192,168,1,10},
                    {192,168,1,20}},
                  {formata_yamerl_ip_addr,formata_yamerl_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,5},{column,3}],
                    {8193,16848,1,28696,0,0,1,2}},
                  {formata_yamerl_ip_netmask,formata_yamerl_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,6},{column,3}],
                    {8193,16848,1,28696,0,0,1,0},
                    64},
                  {formata_yamerl_ip_range,formata_yamerl_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,7},{column,3}],
                    {8193,16848,1,28696,0,0,1,2},
                    {8193,16848,1,28696,0,0,1,5}},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,9},{column,3}],
                    "Not an IP address"}],
                7}}
          ],
          formata_yamerl_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, true}])
        )
      ]
    }.
