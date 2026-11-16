-module('formata_yaml_SUITE_parsing_ex_9.4_explicit_documents').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_9.4_explicit_documents.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        43,
        true,
        [],
        0,
        44,
        8,
        1,
        false,
        7,
        4,
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
        14,
        13,
        undefined,
        undefined,
        _,
        false,
        [
          {formata_yaml_parsing_error,warning,
            "An implicit key must not span several lines",
            2,3,invalid_implicit_key,
            undefined,[]}
        ],
        [
          {formata_yaml_stream_end,7,4},
          {formata_yaml_doc_end,7,1},
          {formata_yaml_scalar,7,1,
            {formata_yaml_tag,7,1,{non_specific,"?"}},
            flow,plain,""},
          {formata_yaml_doc_start,5,1,{1,2},_},
          {formata_yaml_doc_end,4,1},
          {formata_yaml_collection_end,3,8,flow,mapping},
          {formata_yaml_scalar,3,5,
            {formata_yaml_tag,3,5,{non_specific,"?"}},
            flow,plain,"20"},
          {formata_yaml_mapping_value,3,3},
          {formata_yaml_scalar,2,3,
            {formata_yaml_tag,2,3,{non_specific,"?"}},
            flow,plain,"matches %"},
          {formata_yaml_mapping_key,2,3},
          {formata_yaml_collection_start,2,1,
            {formata_yaml_tag,2,1,{non_specific,"?"}},
            flow,mapping},
          {formata_yaml_doc_start,1,1,{1,2},_},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
