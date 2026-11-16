-module('formata_yaml_SUITE_parsing_ex_6.13_reserved_directives').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.13_reserved_directives.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        77,
        true,
        [],
        0,
        78,
        4,
        1,
        false,
        3,
        10,
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
            "Reserved directive \"FOO\" ignored",
            1,1,reserved_directive,
            {formata_yaml_reserved_directive,1,1,"FOO",["bar","baz"],2},
            []}
        ],
        [
          {formata_yaml_stream_end,3,10},
          {formata_yaml_doc_end,3,10},
          {formata_yaml_scalar,3,5,
            {formata_yaml_tag,3,5,{non_specific,"!"}},
            flow,double_quoted,"foo"},
          {formata_yaml_doc_start,3,1,{1,2},_},
          {formata_yaml_reserved_directive,1,1,"FOO",["bar","baz"],2},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
