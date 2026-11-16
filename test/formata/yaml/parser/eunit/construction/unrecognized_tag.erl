-module(formata_yaml_SUITE_construction_unrecognized_tag).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yaml/parser/construction/unrecognized_tag.yaml").

setup() ->
    ok.

ignore_unrecognized_tag_false_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertThrow(
          {formata_yaml_exception, [
              {formata_yaml_parsing_error,error, "Tag \"!unrecognized\" unrecognized by any module", 1, 1, unrecognized_node,
                {formata_yaml_tag, 1, 1, "!unrecognized"},
                []}]},
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, false}])
        )
      ]
    }.

ignore_unrecognized_tag_true_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          ["foobar"],
          formata_yaml_constr:file(?FILENAME,
            [{detailed_constr, false}, {ignore_unrecognized_tags, true}])
        )
      ]
    }.
