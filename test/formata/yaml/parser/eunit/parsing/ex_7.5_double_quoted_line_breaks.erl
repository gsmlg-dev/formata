-module('formata_yaml_SUITE_parsing_ex_7.5_double_quoted_line_breaks').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_7.5_double_quoted_line_breaks.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        63,
        true,
        [],
        0,
        64,
        6,
        1,
        false,
        5,
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
        6,
        5,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yaml_stream_end,5,17},
          {formata_yaml_doc_end,5,17},
          {formata_yaml_scalar,1,1,
            {formata_yaml_tag,1,1,{non_specific,"!"}},
            flow,double_quoted,
            "folded to a space,\nto a line feed, or \t \tnon-content"},
          {formata_yaml_doc_start,1,1,{1,2},_},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
