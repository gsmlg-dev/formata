-module(formata_yamerl_SUITE_parsing_flow_mapping_empty_12).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/flow_mapping_empty_12.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [],
        <<>>,
        4,
        true,
        [],
        0,
        5,
        3,
        1,
        false,
        2,
        2,
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
        [],
        [
          {formata_yamerl_stream_end,2,2},
          {formata_yamerl_doc_end,2,2},
          {formata_yamerl_collection_end,2,1,flow,mapping},
          {formata_yamerl_collection_start,1,1,
            {formata_yamerl_tag,1,1,{non_specific,"?"}},
            flow,mapping},
          {formata_yamerl_doc_start,1,1,{1,2},_},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
