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

-ifndef(internal_formata_yaml_constr_hrl).
-define(internal_formata_yaml_constr_hrl, true).

-include("formata_yaml_nodes.hrl").

%% -------------------------------------------------------------------
%% Options.
%% -------------------------------------------------------------------

-type schema() :: failsafe | json | core | yaml11.
-type formata_yaml_constr_option() :: {detailed_constr, boolean()}
                              | {node_mods, [atom()]}
                              | {schema, schema() | auto}.

%% -------------------------------------------------------------------
%% Representation state.
%% -------------------------------------------------------------------

-record(unfinished_node, {
    module = ?MODULE :: atom(),
    path  :: tuple(),
    pres  :: [tuple()],
    priv  :: any()
  }).

-record(node_anchor, {
    name = "" :: string()
  }).

-record(formata_yaml_constr, {
    options              = []         :: [formata_yaml_constr_option()],
    ext_options          = []         :: [{term(), term()}],
    detailed_constr      = false      :: boolean(),
    mods                 = []         :: [atom()],
    tags                 = []         :: [{tag_uri(), atom()}],
    docs                 = []         :: [formata_yaml_doc() |
                                          formata_yaml_simple_doc()],
    docs_count           = 0          :: non_neg_integer(),
    current_doc          = undefined  :: [formata_yaml_partial_doc() |
                                          formata_yaml_partial_node() |
                                          #unfinished_node{} |
                                          #node_anchor{}]
                                       | undefined,
    current_node_is_leaf = false      :: boolean(),
    anchors              = dict:new() :: dict:dict(term(), term()),
    node_stats           = []         :: [{pos_integer(), pos_integer()}],
    last_node_stats      = {0, 0}     :: {non_neg_integer(), non_neg_integer()},
    expanded_nodes       = 0          :: non_neg_integer()
  }).

-endif.
