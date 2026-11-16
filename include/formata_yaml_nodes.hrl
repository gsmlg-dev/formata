%-
% Copyright (c) 2012-2014 Yakaz
% Copyright (c) 2016-2022 Jean-Sébastien Pédron <jean-sebastien.pedron@dumbbell.fr>
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions
% are met:
% 1. Redistributions of source code must retain the above copyright
%    notice, this list of conditions and the following disclaimer.
% 2. Redistributions in binary form must reproduce the above copyright
%    notice, this list of conditions and the following disclaimer in the
%    documentation and/or other materials provided with the distribution.
%
% THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
% ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
% FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
% DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
% OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
% OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
% SUCH DAMAGE.

-ifndef(formata_yaml_nodes_hrl).
-define(formata_yaml_nodes_hrl, true).

-include("formata_yaml_types.hrl").

%% CAUTION:
%% Records defined in this file have default values for all members.
%% Those default values are often bad values but this is needed so that
%% Erlang won't add "undefined" in our back to the allowed values in the
%% type specifications.

%% -------------------------------------------------------------------
%% Nodes specifications.
%% -------------------------------------------------------------------

%% String (Failsafe Schema).
-record(formata_yaml_str, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    text   = ""                   :: unicode_string()
  }).
-type formata_yaml_str()                :: #formata_yaml_str{}.
-type formata_yaml_simple_str()         :: unicode_string().

%% Null (Core Schema).
-record(formata_yaml_null, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list()
  }).
-type formata_yaml_null()               :: #formata_yaml_null{}.
-type formata_yaml_simple_null()        :: null.

%% Boolean (Core Schema).
-record(formata_yaml_bool, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    value  = true                 :: boolean()
  }).
-type formata_yaml_bool()               :: #formata_yaml_bool{}.
-type formata_yaml_simple_bool()        :: boolean().

%% Integer (Core Schema).
-record(formata_yaml_int, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    value  = 0                    :: integer()
  }).
-type formata_yaml_int()                :: #formata_yaml_int{}.
-type formata_yaml_simple_int()         :: integer().

%% Float (Core Schema).
-record(formata_yaml_float, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    value  = 0.0                  :: float() | '+inf' | '-inf' | 'nan'
  }).
-type formata_yaml_float()              :: #formata_yaml_float{}.
-type formata_yaml_simple_float()       :: float().

%% Binary (Core Schema).
-record(formata_yaml_binary, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    data   = <<"">>               :: bitstring()
  }).
-type formata_yaml_binary()                :: #formata_yaml_binary{}.
-type formata_yaml_simple_binary()         :: bitstring().

%% Erlang atom.
-record(formata_yaml_erlang_atom, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    name                          :: atom()
  }).
-type formata_yaml_erlang_atom()        :: #formata_yaml_erlang_atom{}.
-type formata_yaml_simple_erlang_atom() :: atom().

%% Erlang anonymous function.
-record(formata_yaml_erlang_fun, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    function                      :: function(),
    text                          :: unicode_string()
  }).
-type formata_yaml_erlang_fun()         :: #formata_yaml_erlang_fun{}.
-type formata_yaml_simple_erlang_fun()  :: function().

%% Timestamp.
-type year()   :: non_neg_integer(). %% Types from stdlib/src/calendar.erl.
-type month()  :: 1..12.
-type day()    :: 1..31.
-type hour()   :: 0..23.
-type minute() :: 0..59.
-type second() :: 0..59.
-record(formata_yaml_timestamp, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    year                          :: year() | undefined,
    month                         :: month() | undefined,
    day                           :: day() | undefined,
    hour   = 0                    :: hour(),
    minute = 0                    :: minute(),
    second = 0                    :: second(),
    frac   = 0                    :: non_neg_integer(),
    tz     = 0                    :: integer()
  }).
-type formata_yaml_timestamp()          :: #formata_yaml_timestamp{}.
-type formata_yaml_simple_timestamp()   :: calendar:datetime()
                                   | {undefined, calendar:time()}.

%% Sequence (Failsafe Schema).
-record(formata_yaml_seq, {
    module  = undefined           :: atom(),
    tag     = "!"                 :: tag_uri(),
    pres    = []                  :: list(),
    entries = []                  :: [formata_yaml_node()],
    count   = 0                   :: non_neg_integer()
  }).
-type formata_yaml_seq()                :: #formata_yaml_seq{}.
-type formata_yaml_simple_seq()         :: [formata_yaml_simple_node()].
-type formata_yaml_partial_seq()        :: {
                                       atom(),
                                       {seq, non_neg_integer()},
                                       [
                                         formata_yaml_node()
                                         | formata_yaml_simple_node()
                                         | '$insert_here'
                                       ]
                                     }.

%% Mapping (Failsafe Schema).
-record(formata_yaml_map, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    pairs  = []                   :: [{formata_yaml_node(), formata_yaml_node()}]
  }).
-type formata_yaml_map()                :: #formata_yaml_map{}.
-type formata_yaml_simple_map()         :: [{
                                       formata_yaml_simple_node(),
                                       formata_yaml_simple_node()
                                     }].
-type formata_yaml_partial_map()        :: {
                                       atom(),
                                       {map,
                                         formata_yaml_node()
                                         | formata_yaml_simple_node()
                                         | undefined},
                                       [{
                                         formata_yaml_node()
                                         | formata_yaml_simple_node()
                                         | '$insert_here',
                                         formata_yaml_node()
                                         | formata_yaml_simple_node()
                                         | '$insert_here' | undefined
                                       }]
                                     }.

%% Document.
-record(formata_yaml_doc, {
    root = undefined              :: formata_yaml_node()
                                   | formata_yaml_simple_node() | undefined
  }).
-type formata_yaml_doc()                :: #formata_yaml_doc{root :: formata_yaml_node()}.
-type formata_yaml_simple_doc()         :: formata_yaml_simple_node().
-type formata_yaml_partial_doc()        :: #formata_yaml_doc{}.

%% -------------------------------------------------------------------
%% Final data type specifications.
%% -------------------------------------------------------------------

-type formata_yaml_user_node()          :: tuple().
-type formata_yaml_user_simple_node()   :: term().

-type formata_yaml_node()               :: formata_yaml_seq()
                                   | formata_yaml_map()
                                   | formata_yaml_str()
                                   | formata_yaml_null()
                                   | formata_yaml_bool()
                                   | formata_yaml_int()
                                   | formata_yaml_float()
                                   | formata_yaml_timestamp()
                                   | formata_yaml_erlang_atom()
                                   | formata_yaml_erlang_fun()
                                   | formata_yaml_user_node().

-type formata_yaml_simple_node()        :: formata_yaml_simple_seq()
                                   | formata_yaml_simple_map()
                                   | formata_yaml_simple_str()
                                   | formata_yaml_simple_null()
                                   | formata_yaml_simple_bool()
                                   | formata_yaml_simple_int()
                                   | formata_yaml_simple_float()
                                   | formata_yaml_simple_timestamp()
                                   | formata_yaml_simple_erlang_atom()
                                   | formata_yaml_simple_erlang_fun()
                                   | formata_yaml_user_simple_node().

-type formata_yaml_partial_node()       :: formata_yaml_partial_seq()
                                   | formata_yaml_partial_map()
                                   | formata_yaml_str()
                                   | formata_yaml_null()
                                   | formata_yaml_bool()
                                   | formata_yaml_int()
                                   | formata_yaml_float()
                                   | formata_yaml_timestamp()
                                   | formata_yaml_erlang_atom()
                                   | formata_yaml_erlang_fun()
                                   | formata_yaml_user_node()
                                   | formata_yaml_simple_str()
                                   | formata_yaml_simple_null()
                                   | formata_yaml_simple_bool()
                                   | formata_yaml_simple_int()
                                   | formata_yaml_simple_float()
                                   | formata_yaml_simple_timestamp()
                                   | formata_yaml_simple_erlang_atom()
                                   | formata_yaml_simple_erlang_fun()
                                   | formata_yaml_user_simple_node().

%% -------------------------------------------------------------------
%% Macros to access common members of the node records.
%% -------------------------------------------------------------------

-define(NODE_MOD(N),  element(#formata_yaml_str.module, N)).
-define(NODE_TAG(N),  element(#formata_yaml_str.tag, N)).
-define(NODE_PRES(N), element(#formata_yaml_str.pres, N)).

%% -------------------------------------------------------------------
%% List of modules implementing the Core Schema nodes.
%% -------------------------------------------------------------------

-define(FAILSAFE_SCHEMA_MODS, [
    formata_yaml_node_str,
    formata_yaml_node_seq,
    formata_yaml_node_map
  ]).

-define(JSON_SCHEMA_MODS, [
    formata_yaml_node_null_json,
    formata_yaml_node_bool_json,
    formata_yaml_node_int_json,
    formata_yaml_node_float_json,
    formata_yaml_node_str_json,
    formata_yaml_node_seq,
    formata_yaml_node_map
  ]).

-define(CORE_SCHEMA_MODS, [
    formata_yaml_node_null,
    formata_yaml_node_bool,
    formata_yaml_node_int,
    formata_yaml_node_float,
    formata_yaml_node_str,
    formata_yaml_node_binary,
    formata_yaml_node_seq,
    formata_yaml_node_map
  ]).

-define(YAML11_SCHEMA_MODS, [
    formata_yaml_node_null,
    formata_yaml_node_bool_ext,
    formata_yaml_node_int_ext,
    formata_yaml_node_float_ext,
    formata_yaml_node_str,
    formata_yaml_node_binary,
    formata_yaml_node_seq,
    formata_yaml_node_map
  ]).

-endif.
