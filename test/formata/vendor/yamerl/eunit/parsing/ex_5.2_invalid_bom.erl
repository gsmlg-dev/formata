-module('formata_yamerl_SUITE_parsing_ex_5.2_invalid_bom').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_5.2_invalid_bom.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [],
        <<>>,
        90,
        true,
        [],
        0,
        45,
        4,
        1,
        false,
        3,
        21,
        {utf16,big},
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
        [
          {formata_yamerl_parsing_error,warning,
            _,
            2,1,bom_after_doc_start,undefined,[]}
        ],
        [
          {formata_yamerl_stream_end,3,21},
          {formata_yamerl_doc_end,3,21},
          {formata_yamerl_collection_end,3,21,block,sequence},
          {formata_yamerl_scalar,3,3,
            {formata_yamerl_tag,3,3,{non_specific,"?"}},
            flow,plain,"Inside a document."},
          {formata_yamerl_sequence_entry,3,1},
          {formata_yamerl_scalar,1,3,
            {formata_yamerl_tag,1,3,{non_specific,"?"}},
            flow,plain,"Invalid use of BOM"},
          {formata_yamerl_sequence_entry,1,1},
          {formata_yamerl_collection_start,1,1,
            {formata_yamerl_tag,1,1,{non_specific,"?"}},
            block,sequence},
          {formata_yamerl_doc_start,1,1,{1,2},_},
          {formata_yamerl_stream_start,1,1,{utf16,big}}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
