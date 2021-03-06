%  Copyright 2008, 2010 Konrad-Zuse-Zentrum für Informationstechnik Berlin
%
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
%%%-------------------------------------------------------------------
%%% File    : transaction_SUITE.erl
%%% Author  : Thorsten Schuett <schuett@zib.de>
%%% Description : Unit tests for src/transstore/*.erl
%%%
%%% Created :  14 Mar 2008 by Thorsten Schuett <schuett@zib.de>
%%%-------------------------------------------------------------------
-module(tx_req_list_v2_SUITE).

-author('schuett@zib.de').
-vsn('$Id: tx_req_list_v2_SUITE.erl 906 2010-07-23 14:09:20Z schuett $').

-compile(export_all).

-include("unittest.hrl").

all() ->
    [read, write, tx_req_list].

suite() ->
    [ {timetrap, {seconds, 40}} ].

init_per_suite(Config) ->
    file:set_cwd("../bin"),
    Pid = unittest_helper:make_ring(4),
    [{wrapper_pid, Pid} | Config].

end_per_suite(Config) ->
    %error_logger:tty(false),
    {value, {wrapper_pid, Pid}} = lists:keysearch(wrapper_pid, 1, Config),
    unittest_helper:stop_ring(Pid),
    ok.

read(_Config) ->
    ?equals(cs_api_v2:read("UnknownKey"),
            {fail, not_found}),
    ok.

write(_Config) ->
    ?equals(cs_api_v2:write("WriteKey", "Value"), ok),
    ok.

tx_req_list(_Config) ->
    cs_api_v2:write("A", 7),
    cs_api_v2:read("A"),
    %% write new item
    A = cs_api_v2:process_request_list(cs_api_v2:new_tlog(), [{write, "B", 7}, {commit}]),
    io:format("A: ~p~n", [A]),
    %% read existing item
    B = cs_api_v2:process_request_list(cs_api_v2:new_tlog(), [{read, "A"}, {commit}]),
    io:format("B: ~p~n", [B]),
    %% read non-existing item
    C = cs_api_v2:process_request_list(cs_api_v2:new_tlog(), [{read, "B"}, {commit}]),
    io:format("C: ~p~n", [C]),
    D = cs_api_v2:process_request_list(cs_api_v2:new_tlog(), [{read, "B"},
                                          {read, "B"},
                                          {write, "A", 8},
                                        {read, "A"},
                                          {read, "A"},
                                           {read, "A"},
                                          {write, "B", 9},
                                         {commit}]),
     io:format("D: ~p~n", [D]),
%     ?equals(transaction_api:single_write("Key", "Value"), commit),
%     ?equals(transaction_api:quorum_read("Key"), {"Value", 0}),
    ok.

