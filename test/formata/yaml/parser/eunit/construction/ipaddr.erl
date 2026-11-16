-module(formata_yaml_SUITE_construction_ipaddr).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/ipaddr.yaml").

%% Formata fork: upstream set these node modules through the removed yamerl
%% application environment (yamerl_app:set_param/2); they are passed per call.
-define(NODE_MODS, [formata_yaml_node_ipaddr]).

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
                [{formata_yaml_ip_addr,formata_yaml_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,1},{column,3}],
                    {192,168,1,10}},
                  {formata_yaml_ip_netmask,formata_yaml_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,2},{column,3}],
                    {192,168,1,10},
                    24},
                  {formata_yaml_ip_range,formata_yaml_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,3},{column,3}],
                    {192,168,1,10},
                    {192,168,1,20}},
                  {formata_yaml_ip_addr,formata_yaml_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,5},{column,3}],
                    {8193,16848,1,28696,0,0,1,2}},
                  {formata_yaml_ip_netmask,formata_yaml_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,6},{column,3}],
                    {8193,16848,1,28696,0,0,1,0},
                    64},
                  {formata_yaml_ip_range,formata_yaml_node_ipaddr,
                    "tag:yamerl,2012:ipaddr",
                    [{line,7},{column,3}],
                    {8193,16848,1,28696,0,0,1,2},
                    {8193,16848,1,28696,0,0,1,5}},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,9},{column,3}],
                    "Not an IP address"}],
                7}}
          ],
          formata_yaml_constr:file(?FILENAME, [{node_mods, ?NODE_MODS},{detailed_constr, true}])
        )
      ]
    }.
