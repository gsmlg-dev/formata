-module(formata_yaml_SUITE_parsing_enc_utf8_bom).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/enc_utf8_bom.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        25,
        true,
        [],
        0,
        23,
        2,
        1,
        false,
        1,
        22,
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
        3,
        2,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yaml_stream_end,1,22},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
