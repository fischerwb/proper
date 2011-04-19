-module(pdict_fsm).
-export([test/0, test/1, sample_commands/0]).
-export([initial_state/0, initial_state_data/0, precondition/4, weight/3,
	 postcondition/5, next_state_data/5, empty_pdict/1, non_empty_pdict/1]).
-export([set_up/0, clean_up/0]).

-include_lib("proper/include/proper.hrl").

-define(KEYS, [a,b,c,d]).

%% A simple fsm test for the process dictionary; tests the
%% operations erlang:put/2, erlang:get/1, erlang:erase/1

test() ->
    test(100).

test(N) ->
    proper:quickcheck(?MODULE:prop_pdict(), N).

prop_pdict() ->
    ?FORALL(Cmds, proper_fsm:commands(?MODULE),
	    begin
		{H,S,Res} = proper_fsm:run_commands(?MODULE, Cmds),
		clean_up(),
		?WHENFAIL(
		   io:format("History: ~w\nState: ~w\nRes: ~w\n",
			     [H, S, Res]),
		   aggregate(zip(proper_fsm:state_names(H),
				 command_names(Cmds)),
			     Res == ok))
	    end).

set_up() -> ok.

clean_up() ->
    lists:foreach(fun(Key) -> erlang:erase(Key) end, ?KEYS).

key() ->
    elements(?KEYS).

key(List) ->
    elements(proplists:get_keys(List)).

initial_state() -> empty_pdict.

initial_state_data() -> [].

empty_pdict(_S) ->
    [{non_empty_pdict, {call,erlang,put,[key(),integer()]}}].

non_empty_pdict(S) ->
    [{history, {call,erlang,put,[key(),integer()]}},
     {history, {call,erlang,get,[key(S)]}},
     {history, {call,erlang,erase,[key(S)]}},
     {empty_pdict, {call,erlang,erase,[key(S)]}}].

precondition(non_empty_pdict, non_empty_pdict, S, {call,erlang,erase,[Key]}) ->
    proplists:is_defined(Key, S) andalso proplists:delete(Key, S) =/= [];
precondition(non_empty_pdict, empty_pdict, S, {call,erlang,erase,[Key]}) ->
    proplists:is_defined(Key, S) andalso proplists:delete(Key, S) =:= [];
precondition(_, _, S, {call,erlang,get,[Key]}) ->
    proplists:is_defined(Key, S);
precondition(_, _, _, _) ->
    true.

postcondition(_, _, Props, {call,erlang,put,[Key,_]}, undefined) ->
    not proplists:is_defined(Key, Props);
postcondition(_, _, Props, {call,erlang,put,[Key,_]}, Old) ->
    [{Key,Old}] =:= proplists:lookup_all(Key, Props);
postcondition(_, _, Props, {call,erlang,get,[Key]}, Val) ->
    [{Key,Val}] =:= proplists:lookup_all(Key, Props);
postcondition(_, _, Props, {call,erlang,erase,[Key]}, Val) ->
    [{Key,Val}] =:= proplists:lookup_all(Key, Props);
postcondition(_, _, _, _, _) ->
    false.

next_state_data(_, _, Props, _Var, {call,erlang,put,[Key,Value]}) ->
    %% correct model
    [{Key,Value}|proplists:delete(Key, Props)];
    %% wrong model
    %% Props ++ [{Key,Value}];
next_state_data(_, _, Props, _Var, {call,erlang,erase,[Key]}) ->
    proplists:delete(Key, Props);
next_state_data(_, _, Props, _Var, {call,erlang,get,[_]}) ->
    Props.

weight(_, _, {call,erlang,get,_}) -> 5;
weight(_, _, {call,erlang,erase,_}) -> 2;
weight(_, _, {call,erlang,put,_}) -> 5.

sample_commands() ->
    proper_gen:sample(proper_fsm:commands(?MODULE)).
