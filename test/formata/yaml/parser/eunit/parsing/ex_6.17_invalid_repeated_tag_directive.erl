-module('formata_yaml_SUITE_parsing_ex_6.17_invalid_repeated_tag_directive').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.17_invalid_repeated_tag_directive.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        28,
        true,
        [],
        0,
        29,
        4,
        1,
        false,
        3,
        4,
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
        8,
        7,
        undefined,
        undefined,
        _,
        false,
        [
          {formata_yaml_parsing_error,warning,
            "Multiple declarations of the same handle found: the last one will be used",
            2,1,multiple_tag_handle_declarations,
            {formata_yaml_tag_directive,2,1,"!","!foo"},
            []}
        ],
        [
          {formata_yaml_stream_end,3,4},
          {formata_yaml_doc_end,3,4},
          {formata_yaml_scalar,3,1,
            {formata_yaml_tag,3,1,{non_specific, "?"}},
            flow,plain,"bar"},
          {formata_yaml_doc_start,3,1,{1,2},_},
          {formata_yaml_tag_directive,2,1,"!","!foo"},
          {formata_yaml_tag_directive,1,1,"!","!foo"},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
