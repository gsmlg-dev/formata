-module(formata_yaml_SUITE_parsing_noeol).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/noeol.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
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
          {formata_yaml_stream_end,3,6},
          {formata_yaml_doc_end,3,6},
          {formata_yaml_collection_end,3,6,block,sequence},
          {formata_yaml_scalar,3,3,
            {formata_yaml_tag,3,3,{non_specific,"?"}},
            flow,plain,"two"},
          {formata_yaml_sequence_entry,3,1},
          {formata_yaml_scalar,2,3,
            {formata_yaml_tag,2,3,{non_specific,"?"}},
            flow,plain,"one"},
          {formata_yaml_sequence_entry,2,1},
          {formata_yaml_collection_start,2,1,
            {formata_yaml_tag,2,1,{non_specific,"?"}},
            block,sequence},
          {formata_yaml_doc_start,2,1,{1,2},_},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
