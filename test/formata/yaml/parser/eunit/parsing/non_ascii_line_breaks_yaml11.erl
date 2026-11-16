-module(formata_yaml_SUITE_parsing_non_ascii_line_breaks_yaml11).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/parsing/non_ascii_line_breaks_yaml11.yaml").

single_test_() ->
    ?_assertMatch(
      {formata_yaml_parser,
        {file,?FILENAME},
        [{io_blocksize, 1}],
        <<>>,
        62,
        true,
        [],
        0,
        58,
        7,
        1,
        false,
        5,
        20,
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
          {formata_yaml_stream_end,5,20},
          {formata_yaml_doc_end,5,20},
          {formata_yaml_scalar,3,1,
            {formata_yaml_tag,3,1,{non_specific,"?"}},
            flow,plain,
            "Next line Line separator Paragraph separator"},
          {formata_yaml_doc_start,3,1,{1,1},_},
          {formata_yaml_yaml_directive,1,1,{1,1}},
          {formata_yaml_stream_start,1,1,utf8}
        ]
      },
      formata_yaml_parser:file(?FILENAME, [{io_blocksize, 1}])
    ).
