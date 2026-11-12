-module('formata_yamerl_SUITE_parsing_ex_6.20_tag_handles').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_6.20_tag_handles.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [],
        <<>>,
        52,
        true,
        [],
        0,
        53,
        4,
        1,
        false,
        3,
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
        8,
        6,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yamerl_stream_end,3,13},
          {formata_yamerl_doc_end,3,13},
          {formata_yamerl_scalar,3,8,
            {formata_yamerl_tag,3,1,"tag:example.com,2000:app/foo"},
            flow,double_quoted,"bar"},
          {formata_yamerl_doc_start,2,1,{1,2},_},
          {formata_yamerl_tag_directive,1,1,"!e!","tag:example.com,2000:app/"},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
