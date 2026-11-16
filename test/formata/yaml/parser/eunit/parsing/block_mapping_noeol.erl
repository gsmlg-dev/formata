-module(formata_yaml_SUITE_parsing_block_mapping_noeol).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/block_mapping_noeol.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        24,
        true,
        [],
        0,
        25,
        2,
        5,
        false,
        2,
        5,
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
          {formata_yaml_stream_end,2,5},
          {formata_yaml_doc_end,2,5},
          {formata_yaml_collection_end,2,5,block,mapping},
          {formata_yaml_scalar,2,4,
            {formata_yaml_tag,2,4,{non_specific,"?"}},
            flow,plain,[]},
          {formata_yaml_mapping_value,2,4},
          {formata_yaml_scalar,2,1,
            {formata_yaml_tag,2,1,{non_specific,"?"}},
            flow,plain,"key"},
          {formata_yaml_mapping_key,2,1},
          {formata_yaml_collection_start,2,1,
            {formata_yaml_tag,2,1,{non_specific,"?"}},
            block,mapping},
          {formata_yaml_doc_start,2,1,{1,2}, _},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
