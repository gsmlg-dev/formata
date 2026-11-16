-module('formata_yaml_SUITE_parsing_ex_6.16_tag_directive').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.16_tag_directive.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        51,
        true,
        [],
        0,
        52,
        4,
        1,
        false,
        3,
        16,
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
        6,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yaml_stream_end,3,16},
          {formata_yaml_doc_end,3,16},
          {formata_yaml_scalar,3,11,
            {formata_yaml_tag,3,1,"tag:yaml.org,2002:str"},
            flow,double_quoted,"foo"},
          {formata_yaml_doc_start,2,1,{1,2},_},
          {formata_yaml_tag_directive,1,1,"!yaml!","tag:yaml.org,2002:"},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
