-module('formata_yamerl_SUITE_parsing_ex_8.8_literal_content').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_8.8_literal_content.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [],
        <<>>,
        43,
        true,
        [],
        0,
        44,
        10,
        1,
        false,
        9,
        11,
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
          {formata_yamerl_stream_end,9,11},
          {formata_yamerl_doc_end,9,11},
          {formata_yamerl_scalar,1,1,
            {formata_yamerl_tag,1,1,{non_specific,"!"}},
            block,literal,"\n\nliteral\n \n\ntext\n"},
          {formata_yamerl_doc_start,1,1,{1,2},_},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
