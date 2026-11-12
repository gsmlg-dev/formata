-module('formata_yamerl_SUITE_parsing_ex_5.14_invalid_escaped_characters').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_5.14_invalid_escaped_characters.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [],
        <<>>,
        27,
        true,
        [],
        0,
        28,
        4,
        1,
        false,
        3,
        8,
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
        [
          {formata_yamerl_parsing_error,warning,
            "Invalid escaped character",
            3,3,invalid_escaped_character,
            {formata_yamerl_scalar,2,3,{formata_yamerl_tag,2,3,{non_specific,"!"}},flow,double_quoted,"c "},
            []},
          {formata_yamerl_parsing_error,warning,
            "Invalid escaped character",
            2,4,invalid_escaped_character,
            {formata_yamerl_scalar,2,3,{formata_yamerl_tag,2,3,{non_specific,"!"}},flow,double_quoted,""},
            []}
        ],
        [
          {formata_yamerl_stream_end,3,8},
          {formata_yamerl_doc_end,3,8},
          {formata_yamerl_collection_end,3,8,block,mapping},
          {formata_yamerl_scalar,2,3,
            {formata_yamerl_tag,2,3,{non_specific,"!"}},
            flow,double_quoted,"c xq-"},
          {formata_yamerl_mapping_value,1,12},
          {formata_yamerl_scalar,1,1,
            {formata_yamerl_tag,1,1,{non_specific,"?"}},
            flow,plain,"Bad escapes"},
          {formata_yamerl_mapping_key,1,1},
          {formata_yamerl_collection_start,1,1,
            {formata_yamerl_tag,1,1,{non_specific,"?"}},
            block,mapping},
          {formata_yamerl_doc_start,1,1,{1,2},_},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
