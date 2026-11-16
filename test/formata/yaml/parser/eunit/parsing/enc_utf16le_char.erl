-module(formata_yaml_SUITE_parsing_enc_utf16le_char).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/enc_utf16le_char.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        40,
        true,
        [],
        0,
        21,
        2,
        1,
        false,
        1,
        20,
        {utf16,little},
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
          {formata_yaml_stream_end,1,20},
          {formata_yaml_stream_start,1,1,{utf16,little}}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
