-module(formata_yaml_SUITE_construction_stream).

-include_lib("eunit/include/eunit.hrl").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          ["Hello!"],
          begin
              Stream_St1 = formata_yaml_constr:new("<stdin>"),
              {continue, Stream_St2} = formata_yaml_constr:next_chunk(Stream_St1,
                <<"He">>),
              {continue, Stream_St3} = formata_yaml_constr:next_chunk(Stream_St2,
                <<"ll">>),
              formata_yaml_constr:last_chunk(Stream_St3, <<"o!">>)
          end
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yaml_exception,
            [
              {formata_yaml_parsing_error, error,
                "Unexpected end-of-stream while parsing flow scalar",
                1, 8,
                unexpected_eos,
                {formata_yaml_scalar, 1, 1, {formata_yaml_tag, 1, 1, {non_specific, "!"}},
                  flow, single_quoted,
                  "Hello!"},
                []
              }
            ]
          },
          begin
              Stream_St1 = formata_yaml_constr:new("<stdin>"),
              {continue, Stream_St2} = formata_yaml_constr:next_chunk(Stream_St1,
                <<"'He">>),
              {continue, Stream_St3} = formata_yaml_constr:next_chunk(Stream_St2,
                <<"ll">>),
              formata_yaml_constr:last_chunk(Stream_St3, <<"o!">>)
          end
        )
      ]
    }.
