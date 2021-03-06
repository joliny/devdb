% @copyright 2007-2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin

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
%% @doc log service
%% @version $Id: log.erl 900 2010-07-21 15:56:55Z kruber@zib.de $
-module(log).
-author('schuett@zib.de').
-vsn('$Id: log.erl 900 2010-07-21 15:56:55Z kruber@zib.de $').

-include("log4erl.hrl").

-export([start_link/0]).
-export([log/2, log/3, log/4]).

-type log_level() :: warn | info | error | fatal | debug.

-spec start_link() -> ignore.
start_link() ->
    application:start(log4erl),
    log4erl:add_console_appender(stdout,{info, config:read(log_format)}), 
    log4erl:change_log_level(config:read(log_level)),
    log(info, "Log4erl started"),
    ignore.

-spec log(Level::log_level(), LogMsg::any()) -> any().
log(Level, Log) ->
    log4erl:log(Level,Log).

-spec log(Level::log_level(), LogMsg::any(), Data::any()) -> any().
log(Level, Log, Data) ->
    log4erl:log(Level, Log, Data).

-spec log(Logger::atom(), Level::log_level(), LogMsg::any(), Data::any()) -> any().
log(Logger, Level, Log, Data) ->
    log4erl:log(Logger, Level, Log, Data).
