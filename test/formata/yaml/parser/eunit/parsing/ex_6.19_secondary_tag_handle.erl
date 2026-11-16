-module('formata_yaml_SUITE_parsing_ex_6.19_secondary_tag_handle').

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/ex_6.19_secondary_tag_handle.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [],
        <<>>,
        74,
        true,
        [],
        0,
        75,
        4,
        1,
        false,
        3,
        36,
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
          {formata_yaml_stream_end,3,36},
          {formata_yaml_doc_end,3,36},
          {formata_yaml_scalar,3,7,
            {formata_yaml_tag,3,1,"tag:example.com,2000:app/int"},
            flow,plain,"1 - 3"},
          {formata_yaml_doc_start,2,1,{1,2},_},
          {formata_yaml_tag_directive,1,1,"!!","tag:example.com,2000:app/"},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME)
    ).
