-module('formata_yamerl_SUITE_parsing_ex_6.13_reserved_directives').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_6.13_reserved_directives.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
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
          {formata_yamerl_parsing_error,warning,
            "Reserved directive \"FOO\" ignored",
            1,1,reserved_directive,
            {formata_yamerl_reserved_directive,1,1,"FOO",["bar","baz"],2},
            []}
        ],
        [
          {formata_yamerl_stream_end,3,10},
          {formata_yamerl_doc_end,3,10},
          {formata_yamerl_scalar,3,5,
            {formata_yamerl_tag,3,5,{non_specific,"!"}},
            flow,double_quoted,"foo"},
          {formata_yamerl_doc_start,3,1,{1,2},_},
          {formata_yamerl_reserved_directive,1,1,"FOO",["bar","baz"],2},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
