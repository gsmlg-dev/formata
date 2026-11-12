-module(formata_yamerl_SUITE_parsing_option_token_fun_invalid).

-include_lib("eunit/include/eunit.hrl").

single_test_() ->
    ?_assertThrow(
      {formata_yamerl_exception, [
          {formata_yamerl_invalid_option,error,
            "Invalid value for option \"token_fun\": it must be a function taking the next token as its sole argument, or the atom 'acc' or 'drop'",
            {token_fun,invalid}}
        ]
      },
      formata_yamerl_parser:string(<<>>, [{token_fun, invalid}])
    ).
