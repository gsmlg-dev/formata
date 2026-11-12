-module(formata_yamerl_SUITE_parsing_block_scalar_followed_by_end_of_doc).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/block_scalar_followed_by_end_of_doc.yaml").

single_test_() ->
    ?_assertMatch(
       {formata_yamerl_parser,
        {file, ?FILENAME},
        [],
        <<>>,
        41,
        true,
        [],
        0,
        42,
        7,
        1,
        false,
        6,
        13,
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
        9,
        8,
        undefined,
        undefined,
        _,
        false,
        [],
        [
         {formata_yamerl_stream_end,6,13},
         {formata_yamerl_doc_end,6,13},
         {formata_yamerl_scalar,6,1,
          {formata_yamerl_tag,6,1,{non_specific,"?"}},
          flow,plain,"new document"},
         {formata_yamerl_doc_start,5,1,{1,2}, _},
         {formata_yamerl_doc_end,5,1},
         {formata_yamerl_scalar,1,5,
          {formata_yamerl_tag,1,5,{non_specific,"!"}},
          block,literal,"foo\nbar\nbaz\n"},
         {formata_yamerl_doc_start,1,1,{1,2}, _},
         {formata_yamerl_stream_start,1,1,utf8}
        ]
       },
      formata_yamerl_parser:file(?FILENAME)
    ).
