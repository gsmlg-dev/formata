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

-ifndef(formata_yamerl_nodes_hrl).
-define(formata_yamerl_nodes_hrl, true).

-include("formata_yamerl_types.hrl").

%% CAUTION:
%% Records defined in this file have default values for all members.
%% Those default values are often bad values but this is needed so that
%% Erlang won't add "undefined" in our back to the allowed values in the
%% type specifications.

%% -------------------------------------------------------------------
%% Nodes specifications.
%% -------------------------------------------------------------------

%% String (Failsafe Schema).
-record(formata_yamerl_str, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    text   = ""                   :: unicode_string()
  }).
-type formata_yamerl_str()                :: #formata_yamerl_str{}.
-type formata_yamerl_simple_str()         :: unicode_string().

%% Null (Core Schema).
-record(formata_yamerl_null, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list()
  }).
-type formata_yamerl_null()               :: #formata_yamerl_null{}.
-type formata_yamerl_simple_null()        :: null.

%% Boolean (Core Schema).
-record(formata_yamerl_bool, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    value  = true                 :: boolean()
  }).
-type formata_yamerl_bool()               :: #formata_yamerl_bool{}.
-type formata_yamerl_simple_bool()        :: boolean().

%% Integer (Core Schema).
-record(formata_yamerl_int, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    value  = 0                    :: integer()
  }).
-type formata_yamerl_int()                :: #formata_yamerl_int{}.
-type formata_yamerl_simple_int()         :: integer().

%% Float (Core Schema).
-record(formata_yamerl_float, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    value  = 0.0                  :: float() | '+inf' | '-inf' | 'nan'
  }).
-type formata_yamerl_float()              :: #formata_yamerl_float{}.
-type formata_yamerl_simple_float()       :: float().

%% Binary (Core Schema).
-record(formata_yamerl_binary, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    data   = <<"">>               :: bitstring()
  }).
-type formata_yamerl_binary()                :: #formata_yamerl_binary{}.
-type formata_yamerl_simple_binary()         :: bitstring().

%% Erlang atom.
-record(formata_yamerl_erlang_atom, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    name                          :: atom()
  }).
-type formata_yamerl_erlang_atom()        :: #formata_yamerl_erlang_atom{}.
-type formata_yamerl_simple_erlang_atom() :: atom().

%% Erlang anonymous function.
-record(formata_yamerl_erlang_fun, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    function                      :: function(),
    text                          :: unicode_string()
  }).
-type formata_yamerl_erlang_fun()         :: #formata_yamerl_erlang_fun{}.
-type formata_yamerl_simple_erlang_fun()  :: function().

%% Timestamp.
-type year()   :: non_neg_integer(). %% Types from stdlib/src/calendar.erl.
-type month()  :: 1..12.
-type day()    :: 1..31.
-type hour()   :: 0..23.
-type minute() :: 0..59.
-type second() :: 0..59.
-record(formata_yamerl_timestamp, {
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
-type formata_yamerl_timestamp()          :: #formata_yamerl_timestamp{}.
-type formata_yamerl_simple_timestamp()   :: calendar:datetime()
                                   | {undefined, calendar:time()}.

%% Sequence (Failsafe Schema).
-record(formata_yamerl_seq, {
    module  = undefined           :: atom(),
    tag     = "!"                 :: tag_uri(),
    pres    = []                  :: list(),
    entries = []                  :: [formata_yamerl_node()],
    count   = 0                   :: non_neg_integer()
  }).
-type formata_yamerl_seq()                :: #formata_yamerl_seq{}.
-type formata_yamerl_simple_seq()         :: [formata_yamerl_simple_node()].
-type formata_yamerl_partial_seq()        :: {
                                       atom(),
                                       {seq, non_neg_integer()},
                                       [
                                         formata_yamerl_node()
                                         | formata_yamerl_simple_node()
                                         | '$insert_here'
                                       ]
                                     }.

%% Mapping (Failsafe Schema).
-record(formata_yamerl_map, {
    module = undefined            :: atom(),
    tag    = "!"                  :: tag_uri(),
    pres   = []                   :: list(),
    pairs  = []                   :: [{formata_yamerl_node(), formata_yamerl_node()}]
  }).
-type formata_yamerl_map()                :: #formata_yamerl_map{}.
-type formata_yamerl_simple_map()         :: [{
                                       formata_yamerl_simple_node(),
                                       formata_yamerl_simple_node()
                                     }].
-type formata_yamerl_partial_map()        :: {
                                       atom(),
                                       {map,
                                         formata_yamerl_node()
                                         | formata_yamerl_simple_node()
                                         | undefined},
                                       [{
                                         formata_yamerl_node()
                                         | formata_yamerl_simple_node()
                                         | '$insert_here',
                                         formata_yamerl_node()
                                         | formata_yamerl_simple_node()
                                         | '$insert_here' | undefined
                                       }]
                                     }.

%% Document.
-record(formata_yamerl_doc, {
    root = undefined              :: formata_yamerl_node()
                                   | formata_yamerl_simple_node() | undefined
  }).
-type formata_yamerl_doc()                :: #formata_yamerl_doc{root :: formata_yamerl_node()}.
-type formata_yamerl_simple_doc()         :: formata_yamerl_simple_node().
-type formata_yamerl_partial_doc()        :: #formata_yamerl_doc{}.

%% -------------------------------------------------------------------
%% Final data type specifications.
%% -------------------------------------------------------------------

-type formata_yamerl_user_node()          :: tuple().
-type formata_yamerl_user_simple_node()   :: term().

-type formata_yamerl_node()               :: formata_yamerl_seq()
                                   | formata_yamerl_map()
                                   | formata_yamerl_str()
                                   | formata_yamerl_null()
                                   | formata_yamerl_bool()
                                   | formata_yamerl_int()
                                   | formata_yamerl_float()
                                   | formata_yamerl_timestamp()
                                   | formata_yamerl_erlang_atom()
                                   | formata_yamerl_erlang_fun()
                                   | formata_yamerl_user_node().

-type formata_yamerl_simple_node()        :: formata_yamerl_simple_seq()
                                   | formata_yamerl_simple_map()
                                   | formata_yamerl_simple_str()
                                   | formata_yamerl_simple_null()
                                   | formata_yamerl_simple_bool()
                                   | formata_yamerl_simple_int()
                                   | formata_yamerl_simple_float()
                                   | formata_yamerl_simple_timestamp()
                                   | formata_yamerl_simple_erlang_atom()
                                   | formata_yamerl_simple_erlang_fun()
                                   | formata_yamerl_user_simple_node().

-type formata_yamerl_partial_node()       :: formata_yamerl_partial_seq()
                                   | formata_yamerl_partial_map()
                                   | formata_yamerl_str()
                                   | formata_yamerl_null()
                                   | formata_yamerl_bool()
                                   | formata_yamerl_int()
                                   | formata_yamerl_float()
                                   | formata_yamerl_timestamp()
                                   | formata_yamerl_erlang_atom()
                                   | formata_yamerl_erlang_fun()
                                   | formata_yamerl_user_node()
                                   | formata_yamerl_simple_str()
                                   | formata_yamerl_simple_null()
                                   | formata_yamerl_simple_bool()
                                   | formata_yamerl_simple_int()
                                   | formata_yamerl_simple_float()
                                   | formata_yamerl_simple_timestamp()
                                   | formata_yamerl_simple_erlang_atom()
                                   | formata_yamerl_simple_erlang_fun()
                                   | formata_yamerl_user_simple_node().

%% -------------------------------------------------------------------
%% Macros to access common members of the node records.
%% -------------------------------------------------------------------

-define(NODE_MOD(N),  element(#formata_yamerl_str.module, N)).
-define(NODE_TAG(N),  element(#formata_yamerl_str.tag, N)).
-define(NODE_PRES(N), element(#formata_yamerl_str.pres, N)).

%% -------------------------------------------------------------------
%% List of modules implementing the Core Schema nodes.
%% -------------------------------------------------------------------

-define(FAILSAFE_SCHEMA_MODS, [
    formata_yamerl_node_str,
    formata_yamerl_node_seq,
    formata_yamerl_node_map
  ]).

-define(JSON_SCHEMA_MODS, [
    formata_yamerl_node_null_json,
    formata_yamerl_node_bool_json,
    formata_yamerl_node_int_json,
    formata_yamerl_node_float_json,
    formata_yamerl_node_str_json,
    formata_yamerl_node_seq,
    formata_yamerl_node_map
  ]).

-define(CORE_SCHEMA_MODS, [
    formata_yamerl_node_null,
    formata_yamerl_node_bool,
    formata_yamerl_node_int,
    formata_yamerl_node_float,
    formata_yamerl_node_str,
    formata_yamerl_node_binary,
    formata_yamerl_node_seq,
    formata_yamerl_node_map
  ]).

-define(YAML11_SCHEMA_MODS, [
    formata_yamerl_node_null,
    formata_yamerl_node_bool_ext,
    formata_yamerl_node_int_ext,
    formata_yamerl_node_float_ext,
    formata_yamerl_node_str,
    formata_yamerl_node_binary,
    formata_yamerl_node_seq,
    formata_yamerl_node_map
  ]).

-endif.
