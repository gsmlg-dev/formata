-module('formata_yamerl_SUITE_parsing_ex_9.3_bare_documents').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_9.3_bare_documents.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [],
        <<>>,
        53,
        true,
        [],
        0,
        54,
        8,
        1,
        false,
        8,
        1,
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
          {formata_yamerl_stream_end,8,1},
          {formata_yamerl_doc_end,8,1},
          {formata_yamerl_scalar,6,1,
            {formata_yamerl_tag,6,1,{non_specific,"!"}},
            block,literal,"%!PS-Adobe-2.0\n"},
          {formata_yamerl_doc_start,6,1,{1,2},_},
          {formata_yamerl_doc_end,3,1},
          {formata_yamerl_scalar,1,1,
            {formata_yamerl_tag,1,1,{non_specific,"?"}},
            flow,plain,"Bare document"},
          {formata_yamerl_doc_start,1,1,{1,2},_},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
