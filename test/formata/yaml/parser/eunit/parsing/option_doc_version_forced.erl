-module(formata_yaml_SUITE_parsing_option_doc_version_forced).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/option_doc_version_forced.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [{doc_version, {1,2}}],
        <<>>,
        14,
        true,
        [],
        0,
        15,
        3,
        1,
        false,
        2,
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
        7,
        6,
        undefined,
        undefined,
        _,
        false,
        [],
        [
          {formata_yaml_stream_end,2,4},
          {formata_yaml_doc_end,2,4},
          {formata_yaml_scalar,2,4,
            {formata_yaml_tag,2,4,{non_specific,"?"}},
            flow,plain,[]},
          {formata_yaml_doc_start,2,1,{1,2},_},
          {formata_yaml_yaml_directive,1,1,{0,9}},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{doc_version, {1,2}}])
    ).
