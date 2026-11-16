-module(formata_yaml_SUITE_parsing_dos_newlines).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/dos_newlines.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        70,
        true,
        [],
        0,
        71,
        7,
        1,
        false,
        6,
        10,
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
          {formata_yaml_stream_end,6,10},
          {formata_yaml_doc_end,6,10},
          {formata_yaml_collection_end,6,10,block,sequence},
          {formata_yaml_scalar,5,3,
            {formata_yaml_tag,5,3,{non_specific,"!"}},
            flow,double_quoted,"Hello World"},
          {formata_yaml_sequence_entry,5,1},
          {formata_yaml_scalar,2,3,
            {formata_yaml_tag,2,3,{non_specific,"!"}},
            block,folded,"Hello World\n"},
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
