-module('formata_yamerl_SUITE_parsing_ex_8.10_folded_lines').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_8.10_folded_lines.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [],
        <<>>,
        88,
        true,
        [],
        0,
        89,
        17,
        1,
        false,
        16,
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
        6,
        5,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yamerl_stream_end,16,10},
          {formata_yamerl_doc_end,16,10},
          {formata_yamerl_scalar,1,1,
            {formata_yamerl_tag,1,1,{non_specific,"!"}},
            block,folded,
            "\nfolded line\nnext line\n  * bullet\n\n  * list\n  * lines\n\nlast line\n"},
          {formata_yamerl_doc_start,1,1,{1,2},_},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
