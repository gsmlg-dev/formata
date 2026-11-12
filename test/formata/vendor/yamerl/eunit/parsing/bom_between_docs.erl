-module(formata_yamerl_SUITE_parsing_bom_between_docs).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/bom_between_docs.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        55,
        true,
        [],
        0,
        51,
        6,
        1,
        false,
        5,
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
        9,
        8,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yamerl_stream_end,5,11},
          {formata_yamerl_doc_end,5,11},
          {formata_yamerl_scalar,5,1,
            {formata_yamerl_tag,5,1,{non_specific,"?"}},
            flow,plain,"Document 2"},
          {formata_yamerl_doc_start,5,1,{1,2},_},
          {formata_yamerl_doc_end,3,1},
          {formata_yamerl_scalar,2,1,
            {formata_yamerl_tag,2,1,{non_specific,"?"}},
            flow,plain,"Document 1"},
          {formata_yamerl_doc_start,2,1,{1,2},_},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
