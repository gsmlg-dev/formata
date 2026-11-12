-module(formata_yamerl_SUITE_construction_null).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/null.yaml").

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
          formata_yamerl_constr:file(?FILENAME,
            [{detailed_constr, false}, {schema, failsafe}])
        )
      ]
    }.

schema_json_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yamerl_exception, [
              {formata_yamerl_parsing_error,error, "Invalid string", 1, 3, not_a_string,
                {formata_yamerl_scalar, 1, 3,
                  {formata_yamerl_tag, 1, 3, {non_specific, "?"}},
                  flow, plain, "~"},
                []}]},
          formata_yamerl_constr:file(?FILENAME,
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
          formata_yamerl_constr:file(?FILENAME,
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
            {formata_yamerl_doc,
              {formata_yamerl_seq,formata_yamerl_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [{formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,1},{column,3}],
                    "~"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,2},{column,3}],
                    "null"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,3},{column,3}],
                    "Null"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,4},{column,3}],
                    "NULL"},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,5},{column,1}],
                    ""},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "Not a null"}],
                6}}
          ],
          formata_yamerl_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, failsafe}])
        )
      ]
    }.

schema_json_detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yamerl_exception, [
              {formata_yamerl_parsing_error,error, "Invalid string", 1, 3, not_a_string,
                {formata_yamerl_scalar, 1, 3,
                  {formata_yamerl_tag, 1, 3, {non_specific, "?"}},
                  flow, plain, "~"},
                []}]},
          formata_yamerl_constr:file(?FILENAME,
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
            {formata_yamerl_doc,
              {formata_yamerl_seq,formata_yamerl_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [{formata_yamerl_null,formata_yamerl_node_null,"tag:yaml.org,2002:null",
                    [{line,1},{column,3}]},
                  {formata_yamerl_null,formata_yamerl_node_null,"tag:yaml.org,2002:null",
                    [{line,2},{column,3}]},
                  {formata_yamerl_null,formata_yamerl_node_null,"tag:yaml.org,2002:null",
                    [{line,3},{column,3}]},
                  {formata_yamerl_null,formata_yamerl_node_null,"tag:yaml.org,2002:null",
                    [{line,4},{column,3}]},
                  {formata_yamerl_null,formata_yamerl_node_null,"tag:yaml.org,2002:null",
                    [{line,5},{column,1}]},
                  {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                    [{line,7},{column,3}],
                    "Not a null"}],
                6}}
          ],
          formata_yamerl_constr:file(?FILENAME,
            [{detailed_constr, true}, {schema, core}])
        )
      ]
    }.
