-module('formata_yaml_SUITE_parsing_ex_6.14_yaml_directive').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.14_yaml_directive.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        66,
        true,
        [],
        0,
        67,
        5,
        1,
        false,
        4,
        6,
        utf8,
        false,
        undefined,
        _,
        _,
        [],
        {bcoll,root,0,-1,1,1,-1,1,1},
        false,
        false,
        false,
        [{impl_key,false,false,undefined,undefined,1,1}],
        false,
        false,
        _,
        [],
        0,
        7,
        6,
        undefined,
        undefined,
        _,
        false,
        [
          {formata_yaml_parsing_error,warning,
            "Version 1.3 not supported (maximum version 1.2); parsing may fail",
            3,1,version_not_supported,
            {formata_yaml_doc_start,3,1,{1,3},_},
            []}
        ],
        [
          {formata_yaml_stream_end,4,6},
          {formata_yaml_doc_end,4,6},
          {formata_yaml_scalar,4,1,
            {formata_yaml_tag,4,1,{non_specific,"!"}},
            flow,double_quoted,"foo"},
          {formata_yaml_doc_start,3,1,{1,3},_},
          {formata_yaml_yaml_directive,1,1,{1,3}},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
