-module('formata_yaml_SUITE_parsing_ex_7.6_double_quoted_lines').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_7.6_double_quoted_lines.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        50,
        true,
        [],
        0,
        51,
        5,
        1,
        false,
        4,
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
          {formata_yaml_stream_end,4,17},
          {formata_yaml_doc_end,4,17},
          {formata_yaml_scalar,1,1,
            {formata_yaml_tag,1,1,{non_specific,"!"}},
            flow,double_quoted,
            " 1st non-empty\n2nd non-empty 3rd non-empty "},
          {formata_yaml_doc_start,1,1,{1,2},_},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
