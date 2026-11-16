-module(formata_yaml_SUITE_construction_document_marker_only).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/document_marker_only.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [null],
          formata_yaml_constr:string("---", [{detailed_constr, false}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
           [{formata_yaml_doc,
             {formata_yaml_null, formata_yaml_node_null, "tag:yaml.org,2002:null",
              [{line, 1}, {column, 4}]}}],
          formata_yaml_constr:string("---", [{detailed_constr, true}])
        )
      ]
    }.
