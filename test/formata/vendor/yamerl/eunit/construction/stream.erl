-module(formata_yamerl_SUITE_construction_stream).

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
              Stream_St1 = formata_yamerl_constr:new("<stdin>"),
              {continue, Stream_St2} = formata_yamerl_constr:next_chunk(Stream_St1,
                <<"He">>),
              {continue, Stream_St3} = formata_yamerl_constr:next_chunk(Stream_St2,
                <<"ll">>),
              formata_yamerl_constr:last_chunk(Stream_St3, <<"o!">>)
          end
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yamerl_exception,
            [
              {formata_yamerl_parsing_error, error,
                "Unexpected end-of-stream while parsing flow scalar",
                1, 8,
                unexpected_eos,
                {formata_yamerl_scalar, 1, 1, {formata_yamerl_tag, 1, 1, {non_specific, "!"}},
                  flow, single_quoted,
                  "Hello!"},
                []
              }
            ]
          },
          begin
              Stream_St1 = formata_yamerl_constr:new("<stdin>"),
              {continue, Stream_St2} = formata_yamerl_constr:next_chunk(Stream_St1,
                <<"'He">>),
              {continue, Stream_St3} = formata_yamerl_constr:next_chunk(Stream_St2,
                <<"ll">>),
              formata_yamerl_constr:last_chunk(Stream_St3, <<"o!">>)
          end
        )
      ]
    }.
