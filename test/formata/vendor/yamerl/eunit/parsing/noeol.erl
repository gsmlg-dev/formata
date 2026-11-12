-module(formata_yamerl_SUITE_parsing_noeol).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/noeol.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        31,
        true,
        [],
        0,
        32,
        3,
        6,
        false,
        3,
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
        11,
        10,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yamerl_stream_end,3,6},
          {formata_yamerl_doc_end,3,6},
          {formata_yamerl_collection_end,3,6,block,sequence},
          {formata_yamerl_scalar,3,3,
            {formata_yamerl_tag,3,3,{non_specific,"?"}},
            flow,plain,"two"},
          {formata_yamerl_sequence_entry,3,1},
          {formata_yamerl_scalar,2,3,
            {formata_yamerl_tag,2,3,{non_specific,"?"}},
            flow,plain,"one"},
          {formata_yamerl_sequence_entry,2,1},
          {formata_yamerl_collection_start,2,1,
            {formata_yamerl_tag,2,1,{non_specific,"?"}},
            block,sequence},
          {formata_yamerl_doc_start,2,1,{1,2},_},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
