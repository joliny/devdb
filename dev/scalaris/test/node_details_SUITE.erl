%  @copyright 2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin
%  @end
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
%%% File    node_details_SUITE.erl
%%% @author Nico Kruber <kruber@zib.de>
%%% @doc    Test suites for the node_details module.
%%% @end
%%% Created : 7 Apr 2010 by Nico Kruber <kruber@zib.de>
%%%-------------------------------------------------------------------
%% @version $Id: node_details_SUITE.erl 906 2010-07-23 14:09:20Z schuett $
-module(node_details_SUITE).

-author('kruber@zib.de').
-vsn('$Id: node_details_SUITE.erl 906 2010-07-23 14:09:20Z schuett $').

-compile(export_all).

-include("../include/scalaris.hrl").
-include_lib("unittest.hrl").

all() ->
    [tester_new0, tester_new7,
     tester_set_get_pred,
     tester_set_get_predlist,
     tester_set_get_node,
     tester_set_get_my_range,
     tester_set_get_succ,
     tester_set_get_succlist,
     tester_set_get_load,
     tester_set_get_hostname,
     tester_set_get_rt_size,
     tester_set_get_message_log,
     tester_set_get_memory].

suite() ->
    [
     {timetrap, {seconds, 10}}
    ].

init_per_suite(Config) ->
    file:set_cwd("../bin"),
    error_logger:tty(true),
    Owner = self(),
    Pid = spawn(fun () ->
                        crypto:start(),
                        process_dictionary:start_link(),
                        config:start_link(["scalaris.cfg", "scalaris.local.cfg"]),
                        comm_port:start_link(),
                        timer:sleep(1000),
                        comm_port:set_local_address({127,0,0,1},14195),
                        application:start(log4erl),
                        Owner ! {continue},
                        receive
                            {done} -> ok
                        end
                end),
    receive
        {continue} -> ok
    end,
    [{wrapper_pid, Pid} | Config].

end_per_suite(Config) ->
    {value, {wrapper_pid, Pid}} = lists:keysearch(wrapper_pid, 1, Config),
    gen_component:kill(process_dictionary),
    error_logger:tty(false),
    exit(Pid, kill),
    Config.

-spec safe_compare(NodeDetails::node_details:node_details(),
                   Tag::node_details:node_details_name(),
                   ExpValue::node:node_type() |
                             nodelist:non_empty_snodelist() |
                             intervals:interval() |
                             node_details:load() |
                             node_details:hostname() |
                             node_details:rt_size() |
                             node_details:message_log() |
                             node_details:memory() |
                             unknown) -> true.
safe_compare(NodeDetails, Tag, ExpValue) ->
    case ExpValue of
        unknown -> ?equals_w_note(node_details:contains(NodeDetails, Tag), false, atom_to_list(Tag));
        _       -> ?equals_w_note(node_details:get(NodeDetails, Tag), ExpValue, atom_to_list(Tag))
    end,
    true.

-spec node_details_equals(NodeDetails::node_details:node_details(),
                          Pred::node:node_type() | unknown,
                          PredList::nodelist:non_empty_snodelist() | unknown,
                          Node::node:node_type() | unknown,
                          MyRange::intervals:interval() | unknown,
                          Succ::node:node_type() | unknown,
                          SuccList::nodelist:non_empty_snodelist() | unknown,
                          Load::node_details:load() | unknown,
                          Hostname::node_details:hostname() | unknown,
                          RTSize::node_details:rt_size() | unknown,
                          MsgLog::node_details:message_log() | unknown,
                          Memory::node_details:memory() | unknown) -> true.
node_details_equals(NodeDetails, Pred, PredList, Node, MyRange, Succ, SuccList, Load, Hostname, RTSize, MsgLog, Memory) ->
    safe_compare(NodeDetails, pred, Pred),
    safe_compare(NodeDetails, predlist, PredList),
    safe_compare(NodeDetails, node, Node),
    safe_compare(NodeDetails, my_range, MyRange),
    safe_compare(NodeDetails, succ, Succ),
    safe_compare(NodeDetails, succlist, SuccList),
    safe_compare(NodeDetails, load, Load),
    safe_compare(NodeDetails, hostname, Hostname),
    safe_compare(NodeDetails, rt_size, RTSize),
    safe_compare(NodeDetails, message_log, MsgLog),
    safe_compare(NodeDetails, memory, Memory),
    true.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% node_details:new/0
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-spec test_new0() -> true.
test_new0() ->
    NodeDetails = node_details:new(),
    node_details_equals(NodeDetails, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown).

tester_new0(Config) ->
    tester:test(node_details_SUITE, test_new0, 0, 10),
    Config.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% node_details:new/7
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-spec test_new7(nodelist:non_empty_snodelist(), node:node_type(), nodelist:non_empty_snodelist(), node_details:load(), node_details:hostname(), node_details:rt_size(), node_details:memory()) -> true.
test_new7(PredList, Node, SuccList, Load, Hostname, RTSize, Memory) ->
    NodeDetails = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    node_details_equals(NodeDetails, hd(PredList), PredList, Node, unknown, hd(SuccList), SuccList, Load, Hostname, RTSize, unknown, Memory).

tester_new7(Config) ->
    tester:test(node_details_SUITE, test_new7, 7, 10),
    Config.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% node_details:set/3 and node_details:get/2
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec test_set_get_pred(Pred::node:node_type()) -> true.
test_set_get_pred(PredTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, pred, PredTest),
    NodeDetails2_new = node_details:set(NodeDetails2, pred, PredTest),
    node_details_equals(NodeDetails1_new, PredTest, [PredTest], unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown) andalso
    node_details_equals(NodeDetails2_new, PredTest, [PredTest], Node, unknown, hd(SuccList), SuccList, Load, Hostname, RTSize, unknown, Memory).

-spec test_set_get_predlist(PredList::nodelist:non_empty_snodelist()) -> true.
test_set_get_predlist(PredListTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, predlist, PredListTest),
    NodeDetails2_new = node_details:set(NodeDetails2, predlist, PredListTest),
    node_details_equals(NodeDetails1_new, hd(PredListTest), PredListTest, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown) andalso
    node_details_equals(NodeDetails2_new, hd(PredListTest), PredListTest, Node, unknown, hd(SuccList), SuccList, Load, Hostname, RTSize, unknown, Memory).

-spec test_set_get_node(Node::node:node_type()) -> true.
test_set_get_node(NodeTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, node, NodeTest),
    NodeDetails2_new = node_details:set(NodeDetails2, node, NodeTest),
    node_details_equals(NodeDetails1_new, unknown, unknown, NodeTest, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown) andalso
    node_details_equals(NodeDetails2_new, hd(PredList), PredList, NodeTest, unknown, hd(SuccList), SuccList, Load, Hostname, RTSize, unknown, Memory).

-spec test_set_get_my_range(MyRange::intervals:interval()) -> true.
test_set_get_my_range(MyRangeTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, my_range, MyRangeTest),
    NodeDetails2_new = node_details:set(NodeDetails2, my_range, MyRangeTest),
    node_details_equals(NodeDetails1_new, unknown, unknown, unknown, MyRangeTest, unknown, unknown, unknown, unknown, unknown, unknown, unknown) andalso
    node_details_equals(NodeDetails2_new, hd(PredList), PredList, Node, MyRangeTest, hd(SuccList), SuccList, Load, Hostname, RTSize, unknown, Memory).

-spec test_set_get_succ(Succ::node:node_type()) -> true.
test_set_get_succ(SuccTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, succ, SuccTest),
    NodeDetails2_new = node_details:set(NodeDetails2, succ, SuccTest),
    node_details_equals(NodeDetails1_new, unknown, unknown, unknown, unknown, SuccTest, [SuccTest], unknown, unknown, unknown, unknown, unknown) andalso
    node_details_equals(NodeDetails2_new, hd(PredList), PredList, Node, unknown, SuccTest, [SuccTest], Load, Hostname, RTSize, unknown, Memory).

-spec test_set_get_succlist(SuccList::nodelist:non_empty_snodelist()) -> true.
test_set_get_succlist(SuccListTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, succlist, SuccListTest),
    NodeDetails2_new = node_details:set(NodeDetails2, succlist, SuccListTest),
    node_details_equals(NodeDetails1_new, unknown, unknown, unknown, unknown, hd(SuccListTest), SuccListTest, unknown, unknown, unknown, unknown, unknown) andalso
    node_details_equals(NodeDetails2_new, hd(PredList), PredList, Node, unknown, hd(SuccListTest), SuccListTest, Load, Hostname, RTSize, unknown, Memory).

-spec test_set_get_load(Load::node_details:load()) -> true.
test_set_get_load(LoadTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, load, LoadTest),
    NodeDetails2_new = node_details:set(NodeDetails2, load, LoadTest),
    node_details_equals(NodeDetails1_new, unknown, unknown, unknown, unknown, unknown, unknown, LoadTest, unknown, unknown, unknown, unknown) andalso
    node_details_equals(NodeDetails2_new, hd(PredList), PredList, Node, unknown, hd(SuccList), SuccList, LoadTest, Hostname, RTSize, unknown, Memory).
                          
-spec test_set_get_hostname(Hostname::node_details:hostname()) -> true.
test_set_get_hostname(HostnameTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, hostname, HostnameTest),
    NodeDetails2_new = node_details:set(NodeDetails2, hostname, HostnameTest),
    node_details_equals(NodeDetails1_new, unknown, unknown, unknown, unknown, unknown, unknown, unknown, HostnameTest, unknown, unknown, unknown) andalso
    node_details_equals(NodeDetails2_new, hd(PredList), PredList, Node, unknown, hd(SuccList), SuccList, Load, HostnameTest, RTSize, unknown, Memory).

-spec test_set_get_rt_size(RTSize::node_details:rt_size()) -> true.
test_set_get_rt_size(RTSizeTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, rt_size, RTSizeTest),
    NodeDetails2_new = node_details:set(NodeDetails2, rt_size, RTSizeTest),
    node_details_equals(NodeDetails1_new, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, RTSizeTest, unknown, unknown) andalso
    node_details_equals(NodeDetails2_new, hd(PredList), PredList, Node, unknown, hd(SuccList), SuccList, Load, Hostname, RTSizeTest, unknown, Memory).

-spec test_set_get_message_log(MsgLog::node_details:message_log()) -> true.
test_set_get_message_log(MsgLogTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, message_log, MsgLogTest),
    NodeDetails2_new = node_details:set(NodeDetails2, message_log, MsgLogTest),
    node_details_equals(NodeDetails1_new, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, MsgLogTest, unknown) andalso
    node_details_equals(NodeDetails2_new, hd(PredList), PredList, Node, unknown, hd(SuccList), SuccList, Load, Hostname, RTSize, MsgLogTest, Memory).

-spec test_set_get_memory(Memory::node_details:memory()) -> true.
test_set_get_memory(MemoryTest) ->
    NodeDetails1 = node_details:new(),
    Node = node:new(comm:this(), 0, 0), PredList = [Node], SuccList = [Node],
    Load = 0, Hostname = "localhost", RTSize = 0, Memory = 0,
    NodeDetails2 = node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, Memory),
    NodeDetails1_new = node_details:set(NodeDetails1, memory, MemoryTest),
    NodeDetails2_new = node_details:set(NodeDetails2, memory, MemoryTest),
    node_details_equals(NodeDetails1_new, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, unknown, MemoryTest) andalso
    node_details_equals(NodeDetails2_new, hd(PredList), PredList, Node, unknown, hd(SuccList), SuccList, Load, Hostname, RTSize, unknown, MemoryTest).

tester_set_get_pred(Config) ->
    tester:test(node_details_SUITE, test_set_get_pred, 1, 100),
    Config.

tester_set_get_predlist(Config) ->
    tester:test(node_details_SUITE, test_set_get_predlist, 1, 100),
    Config.

tester_set_get_node(Config) ->
    tester:test(node_details_SUITE, test_set_get_node, 1, 100),
    Config.

tester_set_get_my_range(Config) ->
    tester:test(node_details_SUITE, test_set_get_my_range, 1, 100),
    Config.

tester_set_get_succ(Config) ->
    tester:test(node_details_SUITE, test_set_get_succ, 1, 100),
    Config.

tester_set_get_succlist(Config) ->
    tester:test(node_details_SUITE, test_set_get_succlist, 1, 100),
    Config.

tester_set_get_load(Config) ->
    tester:test(node_details_SUITE, test_set_get_load, 1, 100),
    Config.

tester_set_get_hostname(Config) ->
    tester:test(node_details_SUITE, test_set_get_hostname, 1, 100),
    Config.

tester_set_get_rt_size(Config) ->
    tester:test(node_details_SUITE, test_set_get_rt_size, 1, 100),
    Config.

tester_set_get_message_log(Config) ->
    tester:test(node_details_SUITE, test_set_get_message_log, 1, 100),
    Config.

tester_set_get_memory(Config) ->
    tester:test(node_details_SUITE, test_set_get_memory, 1, 100),
    Config.
