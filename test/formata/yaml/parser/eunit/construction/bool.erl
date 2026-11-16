-module(formata_yaml_SUITE_construction_bool).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/bool.yaml").

setup() ->
    ok.

schema_failsafe_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              "true", "True", "TRUE",
              "y", "Y",
              "yes", "Yes", "YES",
              "on", "On", "ON",
              "false", "False", "FALSE",
              "n", "N",
              "no", "No", "NO",
              "off", "Off", "OFF",
              "Not a bool"
            ]
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, false}, {schema, failsafe}])
        )
      ]
    }.

schema_json_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yaml_exception, [
              {formata_yaml_parsing_error,error, "Invalid string", 2, 3, not_a_string,
                {formata_yaml_scalar, 2, 3,
                  {formata_yaml_tag, 2, 3, {non_specific, "?"}},
                  flow, plain, "True"},
                []}]},
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, false}, {schema, json}])
        )
      ]
    }.

schema_core_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              true, true, true,
              "y", "Y",
              "yes", "Yes", "YES",
              "on", "On", "ON",
              false, false, false,
              "n", "N",
              "no", "No", "NO",
              "off", "Off", "OFF",
              "Not a bool"
            ]
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, false}, {schema, core}])
        )
      ]
    }.

schema_failsafe_bool_ext_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              true, true, true,
              true, true,
              true, true, true,
              true, true, true,
              false, false, false,
              false, false,
              false, false, false,
              false, false, false,
              "Not a bool"
            ]
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, false}, {schema, failsafe},
              {node_mods, [formata_yaml_node_bool_ext]}])
        )
      ]
    }.

schema_failsafe_detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yaml_doc,
              {formata_yaml_seq,formata_yaml_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [{formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,1},{column,3}],
                    "true"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,2},{column,3}],
                    "True"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,3},{column,3}],
                    "TRUE"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,4},{column,3}],
                    "y"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,5},{column,3}],
                    "Y"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,6},{column,3}],
                    "yes"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "Yes"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,8},{column,3}],
                    "YES"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,9},{column,3}],
                    "on"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,10},{column,3}],
                    "On"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,11},{column,3}],
                    "ON"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,13},{column,3}],
                    "false"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,14},{column,3}],
                    "False"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,15},{column,3}],
                    "FALSE"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,16},{column,3}],
                    "n"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,17},{column,3}],
                    "N"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,18},{column,3}],
                    "no"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,19},{column,3}],
                    "No"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,20},{column,3}],
                    "NO"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,21},{column,3}],
                    "off"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,22},{column,3}],
                    "Off"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,23},{column,3}],
                    "OFF"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,25},{column,3}],
                    "Not a bool"}],
                23}
            }
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, failsafe}])
        )
      ]
    }.

schema_json_detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yaml_exception, [
              {formata_yaml_parsing_error,error, "Invalid string", 2, 3, not_a_string,
                {formata_yaml_scalar, 2, 3,
                  {formata_yaml_tag, 2, 3, {non_specific, "?"}},
                  flow, plain, "True"},
                []}]},
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, json}])
        )
      ]
    }.

schema_core_detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yaml_doc,
              {formata_yaml_seq,formata_yaml_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [{formata_yaml_bool,formata_yaml_node_bool,"tag:yaml.org,2002:bool",
                    [{line,1},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool,"tag:yaml.org,2002:bool",
                    [{line,2},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool,"tag:yaml.org,2002:bool",
                    [{line,3},{column,3}],
                    true},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,4},{column,3}],
                    "y"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,5},{column,3}],
                    "Y"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,6},{column,3}],
                    "yes"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "Yes"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,8},{column,3}],
                    "YES"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,9},{column,3}],
                    "on"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,10},{column,3}],
                    "On"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,11},{column,3}],
                    "ON"},
                  {formata_yaml_bool,formata_yaml_node_bool,"tag:yaml.org,2002:bool",
                    [{line,13},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool,"tag:yaml.org,2002:bool",
                    [{line,14},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool,"tag:yaml.org,2002:bool",
                    [{line,15},{column,3}],
                    false},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,16},{column,3}],
                    "n"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,17},{column,3}],
                    "N"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,18},{column,3}],
                    "no"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,19},{column,3}],
                    "No"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,20},{column,3}],
                    "NO"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,21},{column,3}],
                    "off"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,22},{column,3}],
                    "Off"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,23},{column,3}],
                    "OFF"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,25},{column,3}],
                    "Not a bool"}],
                23}
            }
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, core}])
        )
      ]
    }.

schema_failsafe_bool_ext_detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yaml_doc,
              {formata_yaml_seq,formata_yaml_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [{formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,1},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,2},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,3},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,4},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,5},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,6},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,7},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,8},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,9},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,10},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,11},{column,3}],
                    true},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,13},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,14},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,15},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,16},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,17},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,18},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,19},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,20},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,21},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,22},{column,3}],
                    false},
                  {formata_yaml_bool,formata_yaml_node_bool_ext,"tag:yaml.org,2002:bool",
                    [{line,23},{column,3}],
                    false},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,25},{column,3}],
                    "Not a bool"}],
                23}
            }
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, failsafe},
              {node_mods, [formata_yaml_node_bool_ext]}])
        )
      ]
    }.
