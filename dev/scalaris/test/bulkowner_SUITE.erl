%  Copyright 2008 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin
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
%%% File    : bulkowner_SUITE.erl
%%% Author  : Thorsten Schuett <schuett@zib.de>
%%% Description : Unit tests for src/bulkowner.erl
%%%
%%% Created :  26 Aug 2008 by Thorsten Schuett <schuett@zib.de>
%%%-------------------------------------------------------------------
-module(bulkowner_SUITE).

-author('schuett@zib.de').
-vsn('$Id: bulkowner_SUITE.erl 949 2010-07-30 14:16:01Z kruber@zib.de $').

-compile(export_all).

-include("unittest.hrl").

all() ->
    [count].

suite() ->
    [
     {timetrap, {seconds, 10}}
    ].

init_per_suite(Config) ->
    error_logger:tty(true),
    file:set_cwd("../bin"),
    Pid = unittest_helper:make_ring(4),
    [{wrapper_pid, Pid} | Config].

end_per_suite(Config) ->
    error_logger:tty(false),
    {value, {wrapper_pid, Pid}} = lists:keysearch(wrapper_pid, 1, Config),
    unittest_helper:stop_ring(Pid),
    ok.

count(_Config) ->
    ?equals(transaction_api:single_write("i", 2), commit),
    ?equals(transaction_api:single_write("j", 3), commit),
    ?equals(transaction_api:single_write("k", 5), commit),
    ?equals(transaction_api:single_write("l", 7), commit),
    bulkowner:issue_bulk_owner(intervals:all(), {unit_test_bulkowner, self()}),
    ?equals(collect(0), 68),
    ok.

collect(Sum) ->
    if
	Sum < 68 ->
%%         ct:pal("sum: ~p ~p~n", [Sum, Sum]),
	    receive
		{unit_test_bulkowner_response, Data, _Owner} ->
		    collect(Sum + reduce(Data))
	    end;
	Sum == 68 ->
	    receive
		{unit_test_bulkowner_response, Data, _Owner} ->
		    Sum + reduce(Data)
	    after 1000 ->
		    Sum
	    end;
	Sum > 68 ->
	    ct:pal("sum: ~p ~p~n", [Sum, Sum]),
	    Sum
    end.

reduce([]) ->
    0;
reduce([{_, Value}| Rest]) ->
    Value + reduce(Rest).
