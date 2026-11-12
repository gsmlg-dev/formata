-module(formata_yamerl_SUITE_parsing_enc_utf16le_bom).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/enc_utf16le_bom.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        52,
        true,
        [],
        0,
        26,
        2,
        1,
        false,
        1,
        25,
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
          {formata_yamerl_stream_end,1,25},
          {formata_yamerl_stream_start,1,1,{utf16,little}}
        ]
      },
      formata_yamerl_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
