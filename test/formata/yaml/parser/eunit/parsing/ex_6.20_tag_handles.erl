-module('formata_yaml_SUITE_parsing_ex_6.20_tag_handles').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.20_tag_handles.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        52,
        true,
        [],
        0,
        53,
        4,
        1,
        false,
        3,
        13,
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
          {formata_yaml_stream_end,3,13},
          {formata_yaml_doc_end,3,13},
          {formata_yaml_scalar,3,8,
            {formata_yaml_tag,3,1,"tag:example.com,2000:app/foo"},
            flow,double_quoted,"bar"},
          {formata_yaml_doc_start,2,1,{1,2},_},
          {formata_yaml_tag_directive,1,1,"!e!","tag:example.com,2000:app/"},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
