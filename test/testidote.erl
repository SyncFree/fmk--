-module (testidote).
-include("fmk.hrl").

-ifdef(TEST).
-compile(export_all).
-include_lib("eunit/include/eunit.hrl").
-endif.

%% ============================================================================
%% EUnit tests
%% TODO: initializer test should be a fixture.
%% See https://github.com/erlang/rebar3/issues/1166
%% ============================================================================
-ifdef(TEST).
initializer_test() ->
  net_kernel:start(['testidote@127.0.0.1',longnames]),
  erlang:set_cookie(node(),antidote).

antidote_ping_test() ->
  ?assertEqual(pong, net_adm:ping(?ANTIDOTE)).

counter_test() ->
  {ok,_} = fmk_core:write_to_antidote(?TEST_COUNTER_KEY,?COUNTER_TYPE, increment),
  {ok,_} = fmk_core:write_to_antidote(?TEST_COUNTER_KEY,?COUNTER_TYPE, {increment, 2}),
  {ok,_} = fmk_core:write_to_antidote(?TEST_COUNTER_KEY,?COUNTER_TYPE, {increment, 3}),
  ?assertEqual({ok,6}, fmk_core:read_from_antidote(?TEST_COUNTER_KEY,?COUNTER_TYPE)),
  fmk_core:write_to_antidote(?TEST_COUNTER_KEY,?COUNTER_TYPE, decrement),
  fmk_core:write_to_antidote(?TEST_COUNTER_KEY,?COUNTER_TYPE, {decrement, 2}),
  fmk_core:write_to_antidote(?TEST_COUNTER_KEY,?COUNTER_TYPE, {decrement, 3}),
  ?assertEqual({ok,0}, fmk_core:read_from_antidote(?TEST_COUNTER_KEY,?COUNTER_TYPE)).

map_test() ->
  RegisterUpdate = {update,{key, riak_dt_lwwreg},{assign, <<"Awesome">>}},
  CounterUpdate = {update,{val, riak_dt_gcounter},{increment,1}},
  {ok,_} = fmk_core:write_to_antidote(patient123,riak_dt_map, {update,[RegisterUpdate,CounterUpdate]}),
  {ok,_} = fmk_core:read_from_antidote(patient123,riak_dt_map).

-endif.