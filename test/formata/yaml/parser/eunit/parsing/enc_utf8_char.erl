-module(formata_yaml_SUITE_parsing_enc_utf8_char).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/enc_utf8_char.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        17,
        true,
        [],
        0,
        18,
        2,
        1,
        false,
        1,
        17,
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
          {formata_yaml_stream_end,1,17},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
