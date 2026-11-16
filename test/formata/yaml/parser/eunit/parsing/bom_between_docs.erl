-module(formata_yaml_SUITE_parsing_bom_between_docs).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/bom_between_docs.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        55,
        true,
        [],
        0,
        51,
        6,
        1,
        false,
        5,
        11,
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
        [],
        [
          {formata_yaml_stream_end,5,11},
          {formata_yaml_doc_end,5,11},
          {formata_yaml_scalar,5,1,
            {formata_yaml_tag,5,1,{non_specific,"?"}},
            flow,plain,"Document 2"},
          {formata_yaml_doc_start,5,1,{1,2},_},
          {formata_yaml_doc_end,3,1},
          {formata_yaml_scalar,2,1,
            {formata_yaml_tag,2,1,{non_specific,"?"}},
            flow,plain,"Document 1"},
          {formata_yaml_doc_start,2,1,{1,2},_},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
