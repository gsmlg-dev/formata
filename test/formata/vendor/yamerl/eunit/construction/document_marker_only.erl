-module(formata_yamerl_SUITE_construction_document_marker_only).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/construction/document_marker_only.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [null],
          formata_yamerl_constr:string("---", [{detailed_constr, false}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
           [{formata_yamerl_doc,
             {formata_yamerl_null, formata_yamerl_node_null, "tag:yaml.org,2002:null",
              [{line, 1}, {column, 4}]}}],
          formata_yamerl_constr:string("---", [{detailed_constr, true}])
        )
      ]
    }.
