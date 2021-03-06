%  @copyright 2007-2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin

%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%       http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.

%% @author Thorsten Schuett <schuett@zib.de>
%% @doc    Yaws Server wrapper.
%% @end
%% @version $Id: yaws_wrapper.erl 901 2010-07-22 15:18:38Z kruber@zib.de $
-module(yaws_wrapper).
-author('schuett@zib.de').
-vsn('$Id: yaws_wrapper.erl 901 2010-07-22 15:18:38Z kruber@zib.de $').

-include("yaws.hrl").

-export([start_link/3, try_link/3]).

% start yaws
-spec start_link(DocRoot::string(), SL::list(), GL::list()) -> {ok, Pid::pid()} | ignore | {error, Error::{already_started, Pid::pid()} | term()}.
start_link(DocRoot, SL, GL) ->
    ok = application:set_env(yaws, embedded, true),
    ok = application:set_env(yaws, id, "default"),
    Link = yaws_sup:start_link(),
    GC = yaws:create_gconf(GL, "default"),
    SC = yaws:create_sconf(DocRoot, SL),
    %yaws_config:add_yaws_soap_srv(GC),
    SCs = yaws_config:add_yaws_auth([SC]),
    yaws_api:setconf(GC, [SCs]),
    Link.

% try to open yaws
-spec try_link(DocRoot::string(), SL::list(), GL::list()) -> {ok, Pid::pid()} | ignore | {error, Error::{already_started, Pid::pid()} | term()}.
try_link(DocRoot, SL, GL) ->
    ok = application:set_env(yaws, embedded, true),
    ok = application:set_env(yaws, id, "default"),
    Link = yaws_sup:start_link(),
    GC = yaws:create_gconf(GL, "default"),
    SC = yaws:create_sconf(DocRoot, SL),
    %yaws_config:add_yaws_soap_srv(GC),
    SCs = yaws_config:add_yaws_auth([SC]),
    case try_port(SC#sconf.port) of
        true ->
            yaws_api:setconf(GC, [SCs]),
            Link;
        false ->
           log:log(warn,"[ Yaws ] could not start yaws, maybe port ~p is in use~n", [SC#sconf.port]),
            ignore
    end.

-spec try_port(Port::0..65535) -> boolean().
try_port(Port) ->
    case gen_tcp:listen(Port, []) of
        {ok, Sock} ->
            gen_tcp:close(Sock),
            true;
        _  ->
            false
    end.
