-module('formata_yamerl_SUITE_parsing_ex_5.9_directive_indicator').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/parsing/ex_5.9_directive_indicator.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yamerl_parser,
        {file,?FILENAME},
        [],
        <<>>,
        19,
        true,
        [],
        0,
        20,
        3,
        1,
        false,
        2,
        9,
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
        [],
        [
          {formata_yamerl_stream_end,2,9},
          {formata_yamerl_doc_end,2,9},
          {formata_yamerl_scalar,2,5,
            {formata_yamerl_tag,2,5,{non_specific,"?"}},
            flow,plain,"text"},
          {formata_yamerl_doc_start,2,1,{1,2},_},
          {formata_yamerl_yaml_directive,1,1,{1,2}},
          {formata_yamerl_stream_start,1,1,utf8}
        ]
      },
      formata_yamerl_parser:file(?FILENAME)
    ).
