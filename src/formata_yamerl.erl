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

%% @author Jean-Sébastien Pédron <jean-sebastien.pedron@dumbbell.fr>
%% @copyright
%% 2012-2014 Yakaz,
%% 2016-2022 Jean-Sébastien Pédron <jean-sebastien.pedron@dumbbell.fr>
%%
%% @doc Wrappers for common uses of {@link formata_yamerl_constr}.

-module(formata_yamerl).

-include("formata_yamerl_nodes.hrl").
-include("internal/formata_yamerl_constr.hrl").

%% Public API.
-export([
    decode/1,
    decode/2,
    decode_file/1,
    decode_file/2
  ]).

%% -------------------------------------------------------------------
%% Public API: YAML to Erlang.
%% -------------------------------------------------------------------

%% All those functions are only wrapper above formata_yamerl_constr common
%% functions. The purpose is just to avoid some typing.

%% @equiv formata_yamerl_constr:string(String)

-spec decode(String) ->
        Result | no_return() when
          String :: unicode_data(),
          Result :: [formata_yamerl_doc()]
                  | [formata_yamerl_simple_doc()]
                  | term().

decode(String) ->
    formata_yamerl_constr:string(String).

%% @equiv formata_yamerl_constr:string(String, Options)

-spec decode(String, Options) ->
        Result | no_return() when
          String  :: unicode_data(),
          Options :: [ formata_yamerl_parser:formata_yamerl_parser_option()
                     | formata_yamerl_constr_option()
                     | proplists:property()],
          Result  :: [formata_yamerl_doc()]
                   | [formata_yamerl_simple_doc()]
                   | term().

decode(String, Options) ->
    formata_yamerl_constr:string(String, Options).

%% @equiv formata_yamerl_constr:file(Filename)

-spec decode_file(Filename) ->
        Result | no_return() when
          Filename :: string(),
          Result   :: [formata_yamerl_doc()]
                    | [formata_yamerl_simple_doc()]
                    | term().

decode_file(Filename) ->
    formata_yamerl_constr:file(Filename).

%% @equiv formata_yamerl_constr:file(Filename, Options)

-spec decode_file(Filename, Options) ->
        Result | no_return() when
          Filename :: string(),
          Options  :: [ formata_yamerl_parser:formata_yamerl_parser_option()
                      | formata_yamerl_constr_option()
                      | proplists:property()],
          Result   :: [formata_yamerl_doc()]
                    | [formata_yamerl_simple_doc()]
                    | term().

decode_file(Filename, Options) ->
    formata_yamerl_constr:file(Filename, Options).
