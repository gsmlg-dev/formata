-module(formata_yamerl_SUITE_parsing_non_ascii_line_breaks_yaml12).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/non_ascii_line_breaks_yaml12.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        62,
        true,
        [],
        0,
        58,
        4,
        1,
        false,
        3,
        46,
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
        7,
        6,
        undefined,
        undefined,
        _,
        false,
        [
          {formata_yamerl_parsing_error,warning,
            "Use of non-ASCII line break is not supported anymore starting with YAML 1.2; treated as non-break character",
            3,45,non_ascii_line_break,
            undefined,[]},
          {formata_yamerl_parsing_error,warning,
            "Use of non-ASCII line break is not supported anymore starting with YAML 1.2; treated as non-break character",
            3,25,non_ascii_line_break,
            undefined,[]},
          {formata_yamerl_parsing_error,warning,
            "Use of non-ASCII line break is not supported anymore starting with YAML 1.2; treated as non-break character",
            3,10,non_ascii_line_break,
            undefined,[]}
        ],
        [
          {formata_yamerl_stream_end,3,46},
          {formata_yamerl_doc_end,3,46},
          {formata_yamerl_scalar,3,1,
            {formata_yamerl_tag,3,1,{non_specific,"?"}},
            flow,plain,
            [78,101,120,116,32,108,105,110,101,133,76,105,110,101,
              32,115,101,112,97,114,97,116,111,114,8232,80,97,114,
              97,103,114,97,112,104,32,115,101,112,97,114,97,116,
              111,114,8233]},
          {formata_yamerl_doc_start,3,1,{1,2},_},
          {formata_yamerl_yaml_directive,1,1,{1,2}},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
