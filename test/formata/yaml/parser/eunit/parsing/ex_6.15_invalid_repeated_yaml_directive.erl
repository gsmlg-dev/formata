-module('formata_yaml_SUITE_parsing_ex_6.15_invalid_repeated_yaml_directive').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.15_invalid_repeated_yaml_directive.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        24,
        true,
        [],
        0,
        25,
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
            "Multiple YAML directives found: the last one will be used",
            2,1,multiple_yaml_directives,
            {formata_yaml_yaml_directive,2,1,{1,1}},
            []}
        ],
        [
          {formata_yaml_stream_end,3,4},
          {formata_yaml_doc_end,3,4},
          {formata_yaml_scalar,3,1,
            {formata_yaml_tag,3,1,{non_specific,"?"}},
            flow,plain,"foo"},
          {formata_yaml_doc_start,3,1,{1,1},_},
          {formata_yaml_yaml_directive,2,1,{1,1}},
          {formata_yaml_yaml_directive,1,1,{1,2}},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
