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
%% @doc State of a dht_node.
%% @version $Id: dht_node_state.erl 960 2010-08-03 13:53:39Z kruber@zib.de $
-module(dht_node_state).
-author('schuett@zib.de').
-vsn('$Id: dht_node_state.erl 960 2010-08-03 13:53:39Z kruber@zib.de $').

-include("transstore/trecords.hrl").
-include("scalaris.hrl").

-export([new/3,
         get/2,
         set_neighbors/2,
         dump/1,
         set_rt/2,
         set_db/2,
         details/1, details/2,
         add_nc_subscr/3, rm_nc_subscr/3, rm_nc_subscr/2,
         update_node/2,
         %%transactions
         set_trans_log/2,
         set_tx_tp_db/2]).

-ifdef(with_export_type_support).
-export_type([state/0]).
-endif.

-type join_time() :: {MegaSecs::non_neg_integer(), Secs::non_neg_integer(), MicroSecs::non_neg_integer()}.

%% @type state() = {state, gb_trees:gb_tree(), list(), pid()}. the state of a chord# node
-record(state, {rt         :: ?RT:external_rt(),
                neighbors  :: nodelist:neighborhood(),
                join_time  :: join_time(),
                trans_log  :: #translog{},
                db         :: ?DB:db(),
                tx_tp_db   :: any(),
                proposer   :: pid(),
                nc_subscr  :: [{Subscriber::comm:erl_local_pid(), fun((Subscriber::comm:erl_local_pid(), NewNode::node:node_type()) -> any())}] % subscribers to node change events, i.e. node ID changes
               }).
-opaque state() :: #state{}.

%% userdevguide-begin dht_node_state:state
-spec new(?RT:external_rt(), Neighbors::nodelist:neighborhood(),
          ?DB:db()) -> state().
new(RT, Neighbors, DB) ->
    #state{rt = RT,
           neighbors = Neighbors,
           join_time = now(),
           trans_log = #translog{tid_tm_mapping = dict:new(),
                                 decided        = gb_trees:empty(),
                                 undecided      = gb_trees:empty()
                                },
           db = DB,
           tx_tp_db = tx_tp:init(),
           proposer = process_dictionary:get_group_member(paxos_proposer)
          }.
%% userdevguide-end dht_node_state:state

%% @doc Gets the given property from the dht_node state.
%%      Allowed keys include:
%%      <ul>
%%        <li>rt = routing table,</li>
%%        <li>rt_size = size of the routing table (provided for convenience),</li>
%%        <li>succlist = successor list,</li>
%%        <li>succ = successor (provided for convenience),</li>
%%        <li>succ_id = ID of the successor (provided for convenience),</li>
%%        <li>succ_pid = PID of the successor (provided for convenience),</li>
%%        <li>predlist = predecessor list,</li>
%%        <li>pred = predecessor (provided for convenience),</li>
%%        <li>pred_id = ID of the predecessor (provided for convenience),</li>
%%        <li>pred_pid = PID of the predecessor (provided for convenience),</li>
%%        <li>node = the own node,</li>
%%        <li>node_id = the ID of the own node (provided for convenience),</li>
%%        <li>my_range = the range of the own node,</li>
%%        <li>succ_range = the range of the successor,</li>
%%        <li>join_time = the time the node was created, i.e. joined the system,</li>
%%        <li>trans_log = transaction log,</li>
%%        <li>db = DB storing the items,</li>
%%        <li>tx_tp_db = transaction participant DB,</li>
%%        <li>proposer = paxos proposer PID,</li>
%%        <li>load = the load of the own node (provided for convenience).</li>
%%        <li>nc_subscr = list of (local) processes that subscribed to node change events, i.e. node ID changes.</li>
%%      </ul>
-spec get(state(), rt) -> ?RT:external_rt();
         (state(), rt_size) -> non_neg_integer();
         (state(), succlist) -> nodelist:non_empty_snodelist();
         (state(), succ) -> node:node_type();
         (state(), succ_id) -> ?RT:key();
         (state(), succ_pid) -> comm:mypid();
         (state(), predlist) -> nodelist:non_empty_snodelist();
         (state(), pred) -> node:node_type();
         (state(), pred_id) -> ?RT:key();
         (state(), pred_pid) -> comm:mypid();
         (state(), node) -> node:node_type();
         (state(), node_id) -> ?RT:key();
         (state(), my_range) -> intervals:interval();
         (state(), succ_range) -> intervals:interval();
         (state(), join_time) -> join_time();
         (state(), trans_log) -> #translog{};
         (state(), db) -> ?DB:db();
         (state(), tx_tp_db) -> any();
         (state(), proposer) -> pid();
         (state(), load) -> integer();
         (state(), nc_subscr) -> [{Subscriber::comm:erl_local_pid(), fun((Subscriber::comm:erl_local_pid(), NewNode::node:node_type()) -> any())}].
get(#state{rt=RT, neighbors=Neighbors, join_time=JoinTime,
           trans_log=TransLog, db=DB, tx_tp_db=TxTpDb, proposer=Proposer,
           nc_subscr=NCSubscr}, Key) ->
    case Key of
        rt         -> RT;
        rt_size    -> ?RT:get_size(RT);
        succlist   -> nodelist:succs(Neighbors);
        succ       -> nodelist:succ(Neighbors);
        succ_id    -> node:id(nodelist:succ(Neighbors));
        succ_pid   -> node:pidX(nodelist:succ(Neighbors));
        predlist   -> nodelist:preds(Neighbors);
        pred       -> nodelist:pred(Neighbors);
        pred_id    -> node:id(nodelist:pred(Neighbors));
        pred_pid   -> node:pidX(nodelist:pred(Neighbors));
        node       -> nodelist:node(Neighbors);
        node_id    -> nodelist:nodeid(Neighbors);
        my_range   -> node:mk_interval_between_nodes(
                        nodelist:pred(Neighbors),
                        nodelist:node(Neighbors));
        succ_range -> node:mk_interval_between_nodes(
                        nodelist:node(Neighbors),
                        nodelist:succ(Neighbors));
        join_time  -> JoinTime;
        trans_log  -> TransLog;
        db         -> DB;
        tx_tp_db   -> TxTpDb;
        proposer   -> Proposer;
        load       -> ?DB:get_load(DB);
        nc_subscr  -> NCSubscr
    end.

%% @doc Sets the neighborhood of the current node.
-spec set_neighbors(State::state(), NewNeighbors::nodelist:neighborhood()) -> state().
set_neighbors(State, Neighbors) -> State#state{neighbors = Neighbors}.

-spec set_tx_tp_db(State::state(), NewTxTpDb::any()) -> state().
set_tx_tp_db(State, DB) -> State#state{tx_tp_db = DB}.

-spec set_db(State::state(), NewDB::?DB:db()) -> state().
set_db(State, DB) -> State#state{db = DB}.

-spec set_rt(State::state(), NewRT::?RT:external_rt()) -> state().
set_rt(State, RT) -> State#state{rt = RT}.

%% @doc Sets the transaction log.
-spec set_trans_log(State::state(), NewLog::#translog{}) -> state().
set_trans_log(State, NewLog) ->
    State#state{trans_log = NewLog}.

-spec add_nc_subscr(State::state(), Subscriber::comm:erl_local_pid(),
                    fun((Subscriber::comm:erl_local_pid(), NewNode::node:node_type())
                        -> any()))
        -> state().
add_nc_subscr(State = #state{nc_subscr=OldNCSubscr}, Pid, FunToExecute) ->
    State#state{nc_subscr = [{Pid, FunToExecute} | OldNCSubscr]}.

-spec rm_nc_subscr(State::state(), Subscriber::comm:erl_local_pid(),
                   fun((Subscriber::comm:erl_local_pid(), NewNode::node:node_type())
                       -> any()))
        -> state().
rm_nc_subscr(State = #state{nc_subscr=OldNCSubscr}, Pid, FunToExecute) ->
    SubscrTuple = {Pid, FunToExecute},
    State#state{nc_subscr = [X || X <- OldNCSubscr, X =/= SubscrTuple]}.

-spec rm_nc_subscr(State::state(), Subscriber::comm:erl_local_pid())
        -> state().
rm_nc_subscr(State = #state{nc_subscr=OldNCSubscr}, Pid) ->
    State#state{nc_subscr = [E || E = {Subscr, _Fun} <- OldNCSubscr, Subscr =/= Pid]}.

-spec update_node(state(), node:node_type()) -> state().
update_node(State = #state{neighbors=Neighbors}, Node) ->
    State#state{neighbors = nodelist:update_node(Neighbors, Node)}.

%%% util
-spec dump(state()) -> ok.
dump(State) ->
    io:format("dump <~s,~w> <~s,~w> <~s,~w>~n",
              [get(State, node_id), self(),
               get(State, pred_id), get(State, pred_pid),
               get(State, succ_id), get(State, succ_pid)]),
    ok.

%% @doc Gets the requested details about the current node.
-spec details(state(), [node_details:node_details_name()]) -> node_details:node_details().
details(State, Which) ->
    ExtractValues =
        fun(Elem, NodeDetails) ->
                case Elem of
                    hostname    -> node_details:set(NodeDetails, hostname, net_adm:localhost());
                    message_log -> node_details:set(NodeDetails, message_log, ok);
                    memory      -> node_details:set(NodeDetails, memory, erlang:memory(total));
                    Tag         -> node_details:set(NodeDetails, Tag, get(State, Tag))
                end
        end,
    lists:foldl(ExtractValues, node_details:new(), Which).

%% @doc Gets the following details about the current node:
%%      predecessor and successor lists, the node itself, its load, hostname,
%%      routing table size, memory usage.
-spec details(state()) -> node_details:node_details().
details(State) ->
    PredList = get(State, predlist),
    SuccList = get(State, succlist),
    Node = get(State, node),
    Load = get(State, load),
    Hostname = net_adm:localhost(),
    RTSize = get(State, rt_size),
    node_details:new(PredList, Node, SuccList, Load, Hostname, RTSize, erlang:memory(total)).
