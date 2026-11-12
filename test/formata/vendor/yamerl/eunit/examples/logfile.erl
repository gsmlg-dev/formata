-module(formata_yamerl_SUITE_examples_logfile).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/fixtures/yamerl/examples/logfile.yaml").

setup() ->
    ok.

simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              {"Time","2001-11-23 15:01:42 -5"},
              {"User","ed"},
              {"Warning","This is an error message for the log file"}],
            [
              {"Time","2001-11-23 15:02:31 -5"},
              {"User","ed"},
              {"Warning","A slightly different error message."}],
            [
              {"Date","2001-11-23 15:03:17 -5"},
              {"User","ed"},
              {"Fatal","Unknown variable \"bar\""},
              {"Stack",
                [
                  [
                    {"file","TopClass.py"},
                    {"line",23},
                    {"code","x = MoreObject(\"345\\n\")\n"}],
                  [
                    {"file","MoreClass.py"},
                    {"line",58},
                    {"code","foo = bar"}]]}]],
          formata_yamerl_constr:file(?FILENAME, [{detailed_constr, false}])
        )
      ]
    }.

detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {formata_yamerl_doc,{formata_yamerl_map,formata_yamerl_node_map,
                "tag:yaml.org,2002:map",
                [{line,2},{column,1}],
                [
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,2},{column,1}],
                      "Time"},
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,2},{column,7}],
                      "2001-11-23 15:01:42 -5"}},
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,3},{column,1}],
                      "User"},
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,3},{column,7}],
                      "ed"}},
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,4},{column,1}],
                      "Warning"},
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,5},{column,3}],
                      "This is an error message for the log file"}}]}},
            {formata_yamerl_doc,{formata_yamerl_map,formata_yamerl_node_map,
                "tag:yaml.org,2002:map",
                [{line,8},{column,1}],
                [
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,8},{column,1}],
                      "Time"},
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,8},{column,7}],
                      "2001-11-23 15:02:31 -5"}},
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,9},{column,1}],
                      "User"},
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,9},{column,7}],
                      "ed"}},
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,10},{column,1}],
                      "Warning"},
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,11},{column,3}],
                      "A slightly different error message."}}]}},
            {formata_yamerl_doc,{formata_yamerl_map,formata_yamerl_node_map,
                "tag:yaml.org,2002:map",
                [{line,14},{column,1}],
                [
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,14},{column,1}],
                      "Date"},
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,14},{column,7}],
                      "2001-11-23 15:03:17 -5"}},
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,15},{column,1}],
                      "User"},
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,15},{column,7}],
                      "ed"}},
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,16},{column,1}],
                      "Fatal"},
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,17},{column,3}],
                      "Unknown variable \"bar\""}},
                  {
                    {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                      [{line,18},{column,1}],
                      "Stack"},
                    {formata_yamerl_seq,formata_yamerl_node_seq,"tag:yaml.org,2002:seq",
                      [{line,19},{column,3}],
                      [
                        {formata_yamerl_map,formata_yamerl_node_map,"tag:yaml.org,2002:map",
                          [{line,19},{column,5}],
                          [
                            {
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,19},{column,5}],
                                "file"},
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,19},{column,11}],
                                "TopClass.py"}},
                            {
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,20},{column,5}],
                                "line"},
                              {formata_yamerl_int,formata_yamerl_node_int,"tag:yaml.org,2002:int",
                                [{line,20},{column,11}],
                                23}},
                            {
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,21},{column,5}],
                                "code"},
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,21},{column,11}],
                                "x = MoreObject(\"345\\n\")\n"}}]},
                        {formata_yamerl_map,formata_yamerl_node_map,"tag:yaml.org,2002:map",
                          [{line,23},{column,5}],
                          [
                            {
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,23},{column,5}],
                                "file"},
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,23},{column,11}],
                                "MoreClass.py"}},
                            {
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,24},{column,5}],
                                "line"},
                              {formata_yamerl_int,formata_yamerl_node_int,"tag:yaml.org,2002:int",
                                [{line,24},{column,11}],
                                58}},
                            {
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,25},{column,5}],
                                "code"},
                              {formata_yamerl_str,formata_yamerl_node_str,"tag:yaml.org,2002:str",
                                [{line,25},{column,11}],
                                "foo = bar"}}]}],
                      2}}]}}
          ],
          formata_yamerl_constr:file(?FILENAME, [{detailed_constr, true}])
        )
      ]
    }.
