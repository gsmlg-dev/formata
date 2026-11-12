-module(formata_yamerl_SUITE_parsing_empty).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/empty.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [],
        <<>>,
        0,
        true,
        [],
        0,
        1,
        1,
        1,
        false,
        1,
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
        3,
        2,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yamerl_stream_end,1,1},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
