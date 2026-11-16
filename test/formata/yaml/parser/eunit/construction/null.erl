-module(formata_yaml_SUITE_construction_null).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/null.yaml").

setup() ->
    ok.

schema_failsafe_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            ["~", "null", "Null", "NULL", "", "Not a null"]
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
              {formata_yaml_parsing_error,error, "Invalid string", 1, 3, not_a_string,
                {formata_yaml_scalar, 1, 3,
                  {formata_yaml_tag, 1, 3, {non_specific, "?"}},
                  flow, plain, "~"},
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
            [null, null, null, null, null, "Not a null"]
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, false}, {schema, core}])
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
                    "~"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,2},{column,3}],
                    "null"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,3},{column,3}],
                    "Null"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,4},{column,3}],
                    "NULL"},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,5},{column,1}],
                    ""},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "Not a null"}],
                6}}
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
              {formata_yaml_parsing_error,error, "Invalid string", 1, 3, not_a_string,
                {formata_yaml_scalar, 1, 3,
                  {formata_yaml_tag, 1, 3, {non_specific, "?"}},
                  flow, plain, "~"},
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
                [{formata_yaml_null,formata_yaml_node_null,"tag:yaml.org,2002:null",
                    [{line,1},{column,3}]},
                  {formata_yaml_null,formata_yaml_node_null,"tag:yaml.org,2002:null",
                    [{line,2},{column,3}]},
                  {formata_yaml_null,formata_yaml_node_null,"tag:yaml.org,2002:null",
                    [{line,3},{column,3}]},
                  {formata_yaml_null,formata_yaml_node_null,"tag:yaml.org,2002:null",
                    [{line,4},{column,3}]},
                  {formata_yaml_null,formata_yaml_node_null,"tag:yaml.org,2002:null",
                    [{line,5},{column,1}]},
                  {formata_yaml_str,formata_yaml_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "Not a null"}],
                6}}
          ],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, core}])
        )
      ]
    }.
