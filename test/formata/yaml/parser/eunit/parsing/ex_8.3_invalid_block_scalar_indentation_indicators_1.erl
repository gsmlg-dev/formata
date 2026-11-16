-module('formata_yaml_SUITE_parsing_ex_8.3_invalid_block_scalar_indentation_indicators_1').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_8.3_invalid_block_scalar_indentation_indicators_1.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        13,
        true,
        [],
        0,
        14,
        4,
        1,
        false,
        4,
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
        [
          {formata_yaml_parsing_error,warning,
            "A leading all-space line has too many spaces (2) compared to detected indentation (1)",
            3,2,leading_empty_lines_too_long,
            {formata_yaml_scalar,1,3,{formata_yaml_tag,1,3,{non_specific,"!"}},block,literal,[]},
            []}
        ],
        [
          {formata_yaml_stream_end,4,1},
          {formata_yaml_doc_end,4,1},
          {formata_yaml_collection_end,4,1,block,sequence},
          {formata_yaml_scalar,1,3,
            {formata_yaml_tag,1,3,{non_specific,"!"}},
            block,literal,"\ntext\n"},
          {formata_yaml_sequence_entry,1,1},
          {formata_yaml_collection_start,1,1,
            {formata_yaml_tag,1,1,{non_specific,"?"}},
            block,sequence},
          {formata_yaml_doc_start,1,1,{1,2},_},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
