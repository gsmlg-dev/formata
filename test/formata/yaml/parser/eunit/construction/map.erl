-module(formata_yaml_SUITE_construction_map).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/map.yaml").

setup() ->
    ok.

proplist_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              {"first", [{"item", 1}]},
              {"second", [{"item", 2}]},
              {"third", [{"item", 3}]}
            ]
          ],
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, false}])
        )
      ]
    }.

proplist_simple_keep_duplicate_keys_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              {"first", [{"item", 1}]},
              {"second", [{"item", 2}]},
              {"third", [{"item", 2}, {"item", 3}]}
            ]
          ],
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, false}, {keep_duplicate_keys, true}])
        )
      ]
    }.

proplist_detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yaml_doc,
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                [{line,1},{column,1}],
                [{{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                      [{line,1},{column,1}],
                      "first"},
                    {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                      [{line,1},{column,9}],
                      [{{formata_yaml_str,formata_yaml_node_str,
                            "tag:yaml.org,2002:str",
                            [{line,1},{column,11}],
                            "item"},
                          {formata_yaml_int,formata_yaml_node_int,
                            "tag:yaml.org,2002:int",
                            [{line,1},{column,17}],
                            1}}]}},
                  {{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                      [{line,2},{column,1}],
                      "second"},
                    {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                      [{line,2},{column,9}],
                      [{{formata_yaml_str,formata_yaml_node_str,
                            "tag:yaml.org,2002:str",
                            [{line,2},{column,11}],
                            "item"},
                          {formata_yaml_int,formata_yaml_node_int,
                            "tag:yaml.org,2002:int",
                            [{line,2},{column,17}],
                            2}}]}},
                  {{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                      [{line,3},{column,1}],
                      "third"},
                    {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                      [{line,3},{column,9}],
                      [{{formata_yaml_str,formata_yaml_node_str,
                            "tag:yaml.org,2002:str",
                            [{line,3},{column,20}],
                            "item"},
                          {formata_yaml_int,formata_yaml_node_int,
                            "tag:yaml.org,2002:int",
                            [{line,3},{column,26}],
                            3}}]}}]}}
          ],
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, true}])
        )
      ]
    }.

proplist_detailed_keep_duplicate_keys_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yaml_doc,
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                [{line,1},{column,1}],
                [{{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                      [{line,1},{column,1}],
                      "first"},
                    {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                      [{line,1},{column,9}],
                      [{{formata_yaml_str,formata_yaml_node_str,
                            "tag:yaml.org,2002:str",
                            [{line,1},{column,11}],
                            "item"},
                          {formata_yaml_int,formata_yaml_node_int,
                            "tag:yaml.org,2002:int",
                            [{line,1},{column,17}],
                            1}}]}},
                  {{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                      [{line,2},{column,1}],
                      "second"},
                    {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                      [{line,2},{column,9}],
                      [{{formata_yaml_str,formata_yaml_node_str,
                            "tag:yaml.org,2002:str",
                            [{line,2},{column,11}],
                            "item"},
                          {formata_yaml_int,formata_yaml_node_int,
                            "tag:yaml.org,2002:int",
                            [{line,2},{column,17}],
                            2}}]}},
                  {{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                      [{line,3},{column,1}],
                      "third"},
                    {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                      [{line,3},{column,9}],
                      [{{formata_yaml_str,formata_yaml_node_str,
                              "tag:yaml.org,2002:str",
                              [{line,3},{column,11}],
                              "item"},
                          {formata_yaml_int,formata_yaml_node_int,
                              "tag:yaml.org,2002:int",
                              [{line,3},{column,17}],
                              2}},
                          {{formata_yaml_str,formata_yaml_node_str,
                              "tag:yaml.org,2002:str",
                              [{line,3},{column,20}],
                              "item"},
                          {formata_yaml_int,formata_yaml_node_int,
                              "tag:yaml.org,2002:int",
                              [{line,3},{column,26}],
                              3}}]}}]}}
          ],
          formata_yaml_constr:file(?FILENAME, [{detailed_constr, true}, {keep_duplicate_keys, true}])
        )
      ]
    }.

map_simple_test_() ->
    case erlang:function_exported(maps, from_list, 1) of
        true  -> map_simple();
        false -> []
    end.

map_simple() ->
    SubMap1 = maps:from_list([{"item", 1}]),
    SubMap2 = maps:from_list([{"item", 2}]),
    SubMap3 = maps:from_list([{"item", 3}]),
    Map = maps:from_list([
        {"first", SubMap1},
        {"second", SubMap2},
        {"third", SubMap3}
      ]),
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            Map
          ],
          formata_yaml_constr:file(?FILENAME, [
              {detailed_constr, false},
              {map_node_format, map}
            ])
        )
      ]
    }.

map_detailed_test_() ->
    case erlang:function_exported(maps, from_list, 1) of
        true  -> map_detailed();
        false -> []
    end.

map_detailed() ->
    SubMap1 = maps:from_list(
                [{{formata_yaml_str,formata_yaml_node_str,
                   "tag:yaml.org,2002:str",
                   [{line,1},{column,11}],
                   "item"},
                  {formata_yaml_int,formata_yaml_node_int,
                   "tag:yaml.org,2002:int",
                   [{line,1},{column,17}],
                   1}}
                ]),
    SubMap2 = maps:from_list(
                [{{formata_yaml_str,formata_yaml_node_str,
                   "tag:yaml.org,2002:str",
                   [{line,2},{column,11}],
                   "item"},
                  {formata_yaml_int,formata_yaml_node_int,
                   "tag:yaml.org,2002:int",
                   [{line,2},{column,17}],
                   2}}]),
    SubMap3 = maps:from_list(
                [{{formata_yaml_str,formata_yaml_node_str,
                   "tag:yaml.org,2002:str",
                   [{line,3},{column,20}],
                   "item"},
                  {formata_yaml_int,formata_yaml_node_int,
                   "tag:yaml.org,2002:int",
                   [{line,3},{column,26}],
                   3}}]),
    Map = maps:from_list(
            [{{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
               [{line,1},{column,1}],
               "first"},
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
               [{line,1},{column,9}],
               SubMap1}},
             {{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
               [{line,2},{column,1}],
               "second"},
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
               [{line,2},{column,9}],
               SubMap2}},
             {{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
               [{line,3},{column,1}],
               "third"},
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
               [{line,3},{column,9}],
               SubMap3}}]),
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yaml_doc,
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                [{line,1},{column,1}],
                Map}}
          ],
          formata_yaml_constr:file(?FILENAME, [
              {detailed_constr, true},
              {map_node_format, map}
            ])
        )
      ]
    }.

map_detailed_keep_duplicate_keys_test_() ->
    SubMap1 = maps:from_list(
                [{{formata_yaml_str,formata_yaml_node_str,
                   "tag:yaml.org,2002:str",
                   [{line,1},{column,11}],
                   "item"},
                  {formata_yaml_int,formata_yaml_node_int,
                   "tag:yaml.org,2002:int",
                   [{line,1},{column,17}],
                   1}}
                ]),
    SubMap2 = maps:from_list(
                [{{formata_yaml_str,formata_yaml_node_str,
                   "tag:yaml.org,2002:str",
                   [{line,2},{column,11}],
                   "item"},
                  {formata_yaml_int,formata_yaml_node_int,
                   "tag:yaml.org,2002:int",
                   [{line,2},{column,17}],
                   2}}]),
    SubMap3 = maps:from_list(
                [{{formata_yaml_str,formata_yaml_node_str,
                    "tag:yaml.org,2002:str",
                    [{line,3},{column,11}],
                    "item"},
                    {formata_yaml_int,formata_yaml_node_int,
                    "tag:yaml.org,2002:int",
                    [{line,3},{column,17}],
                    2}},
                  {{formata_yaml_str,formata_yaml_node_str,
                   "tag:yaml.org,2002:str",
                   [{line,3},{column,20}],
                   "item"},
                  {formata_yaml_int,formata_yaml_node_int,
                   "tag:yaml.org,2002:int",
                   [{line,3},{column,26}],
                   3}}]),
    Map = maps:from_list(
            [{{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
               [{line,1},{column,1}],
               "first"},
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
               [{line,1},{column,9}],
               SubMap1}},
             {{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
               [{line,2},{column,1}],
               "second"},
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
               [{line,2},{column,9}],
               SubMap2}},
             {{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
               [{line,3},{column,1}],
               "third"},
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
               [{line,3},{column,9}],
               SubMap3}}]),
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yaml_doc,
              {formata_yaml_map,formata_yaml_node_map,"tag:yaml.org,2002:map",
                [{line,1},{column,1}],
                Map}}
          ],
          formata_yaml_constr:file(?FILENAME, [
              {detailed_constr, true},
              {keep_duplicate_keys, true},
              {map_node_format, map}
            ])
        )
      ]
    }.
