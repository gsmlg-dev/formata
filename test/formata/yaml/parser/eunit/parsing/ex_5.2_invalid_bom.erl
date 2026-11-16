-module('formata_yaml_SUITE_parsing_ex_5.2_invalid_bom').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_5.2_invalid_bom.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
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
          {formata_yaml_parsing_error,warning,
            _,
            2,1,bom_after_doc_start,undefined,[]}
        ],
        [
          {formata_yaml_stream_end,3,21},
          {formata_yaml_doc_end,3,21},
          {formata_yaml_collection_end,3,21,block,sequence},
          {formata_yaml_scalar,3,3,
            {formata_yaml_tag,3,3,{non_specific,"?"}},
            flow,plain,"Inside a document."},
          {formata_yaml_sequence_entry,3,1},
          {formata_yaml_scalar,1,3,
            {formata_yaml_tag,1,3,{non_specific,"?"}},
            flow,plain,"Invalid use of BOM"},
          {formata_yaml_sequence_entry,1,1},
          {formata_yaml_collection_start,1,1,
            {formata_yaml_tag,1,1,{non_specific,"?"}},
            block,sequence},
          {formata_yaml_doc_start,1,1,{1,2},_},
          {formata_yaml_stream_start,1,1,{utf16,big}}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
