-module('formata_yaml_SUITE_parsing_ex_6.7_block_folding').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.7_block_folding.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        26,
        true,
        [],
        0,
        27,
        7,
        1,
        false,
        7,
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
        6,
        5,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yaml_stream_end,7,1},
          {formata_yaml_doc_end,7,1},
          {formata_yaml_scalar,1,1,
            {formata_yaml_tag,1,1,{non_specific,"!"}},
            block,folded,"foo \n\n\t bar\n\nbaz\n"},
          {formata_yaml_doc_start,1,1,{1,2},_},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
