#!/usr/bin/env escript
%% -*- erlang -*-
%%! -smp enable -name setup@127.0.0.1 -cookie fmke -mnesia debug verbose
-mode(compile).
-define(ZIPF_SKEW, 1).
-define(NUMTHREADS, 30).
-define(MAX_RETRIES, 10).

-record(fmkeconfig, {
  numpatients,
  numpharmacies,
  numfacilities,
  numstaff,
  numprescriptions
}).

main([Database, ConfigFile, Node | []]) ->
  populate(Database, ConfigFile, [Node]);

main([Database, ConfigFile | Nodes = [_H|_T]]) ->
  populate(Database, ConfigFile, Nodes);

main(_) ->
  usage().

usage() ->
  io:format("usage: data_store config_file fmke_node\n"),
  halt(1).

populate(Database, ConfigFile, FMKeNodes) ->
  io:format("Running population script with ~p backend.~n",[Database]),
  {ok, Cwd} = file:get_cwd(),
  Filename = Cwd ++ "/config/" ++ ConfigFile,
  io:format("Reading configuration file from ~p...~n",[Filename]),
  Nodes = lists:map(fun(Node) -> list_to_atom(Node) end, FMKeNodes),
  io:format("Sending FMKe population ops to the following nodes:~n~p~n", [Nodes]),
  {ok, ConfigProps} = file:consult(Filename),
  Config = #fmkeconfig{
    numpatients = proplists:get_value(numpatients, ConfigProps),
    numpharmacies = proplists:get_value(numpharmacies, ConfigProps),
    numfacilities = proplists:get_value(numfacilities, ConfigProps),
    numstaff = proplists:get_value(numstaff, ConfigProps),
    numprescriptions = proplists:get_value(numprescriptions, ConfigProps)
  },

  MyNodeName = "fmke_populator@127.0.0.1",

  io:format("Node name set to ~p.\n", [MyNodeName]),
  io:format("The population script is going to create the following entities:~n",[]),
  io:format("-~p patients~n",[Config#fmkeconfig.numpatients]),
  io:format("-~p pharmacies~n",[Config#fmkeconfig.numpharmacies]),
  io:format("-~p hospitals~n",[Config#fmkeconfig.numfacilities]),
  io:format("-~p doctors~n",[Config#fmkeconfig.numstaff]),
  io:format("-~p prescriptions~n",[Config#fmkeconfig.numprescriptions]),
  net_kernel:start([MyNodeName, longnames]),
  erlang:set_cookie(node(), fmke),
  %% check if all nodes are running and reachable via distributed erlang
  case multi_ping(Nodes) of
    pang ->
      io:format("[Fatal]: Cannot connect to FMKe.\n");
    pong ->
      io:format("Populating ~p...\n", [Database]),
      case populate_db(Nodes, Config) of
        {ok, 0, _} ->
          io:format("Population unsuccessful, please check if the database already contains records from previous benchmarks.~n"),
          halt(1);
        {ok, NumOkOps, NumUnsuccessfulOps} ->
          io:format("Successfully populated ~p (~p insertions out of ~p).~n",
          [Database, NumOkOps, NumOkOps+NumUnsuccessfulOps])
      end
  end.

multi_ping([]) -> pong;
multi_ping([H|T]) ->
  case net_adm:ping(H) of
    pang -> pang;
    pong -> multi_ping(T)
  end.

populate_db(Nodes, Config) ->
  {ok, S1, E1} = add_patients(Nodes, Config#fmkeconfig.numpatients),
  {ok, S2, E2} = add_pharmacies(Nodes, Config#fmkeconfig.numpharmacies),
  {ok, S3, E3} = add_facilities(Nodes, Config#fmkeconfig.numfacilities),
  {ok, S4, E4} = add_staff(Nodes, Config#fmkeconfig.numstaff),
  {ok, S5, E5} = add_prescriptions(Nodes, Config#fmkeconfig.numprescriptions, Config),
  {ok, S1 + S2 + S3 + S4 + S5, E1 + E2 + E3 + E4 + E5}.

parallel_create(Name, Amount, Fun) ->
  NumProcs = ?NUMTHREADS,
  Divisions = calculate_divisions(Amount, NumProcs),
  spawn_workers(self(), NumProcs, Divisions, Fun),
  supervisor_loop(Name, 0, Amount).

spawn_workers(_Pid, 0, [], _Fun) -> ok;
spawn_workers(Pid, ProcsLeft, [H|T], Fun) ->
  spawn(fun() -> lists:map(fun(Id) -> create(Pid, Id, Fun) end, H) end),
  spawn_workers(Pid, ProcsLeft - 1, T, Fun).

supervisor_loop(Name, NumOps, Total) ->
  supervisor_loop(Name, NumOps, Total, {0, 0}).

supervisor_loop(_Name, Total, Total, {Suc, Err}) -> {ok, Suc, Err};
supervisor_loop(Name, NumOps, Total, {Suc, Err}) ->
  receive
    {done, ok, _SeqNumber} ->
      CurrentProgress = 100 * (NumOps + 1) / Total,
      CurrentProgTrunc = trunc(CurrentProgress),
      case CurrentProgress == CurrentProgTrunc andalso CurrentProgTrunc rem 10 =:= 0 of
        true ->
          io:format("Creating ~p... ~p%~n", [Name, CurrentProgTrunc]),
          ok;
        false ->
          ok
      end,
      supervisor_loop(Name, NumOps + 1, Total, {Suc + 1, Err});
    {done, {error, _Reason}, _SeqNumber} ->
      % io:format("Error creating ~p #~p...~n~p~n", [Name, SeqNumber, Reason]),
      supervisor_loop(Name, NumOps + 1, Total, {Suc, Err + 1})
  end.

create(Pid, Id, Fun) ->
  Result = Fun(Id),
  Pid ! {done, Result, Id}.

calculate_divisions(Amount, NumProcs) ->
  AmountPerProc = Amount div NumProcs,
  lists:map(
    fun(ProcNum) ->
      Start = (ProcNum-1) * AmountPerProc + 1,
      End = case ProcNum =:= NumProcs of
        true -> Amount;
        false -> Start + AmountPerProc - 1
      end,
      lists:seq(Start, End)
    end,
    lists:seq(1, NumProcs)).

add_pharmacies(Nodes, Amount) ->
  parallel_create(pharmacies, Amount,
    fun(I) ->
      Node = lists:nth(I rem length(Nodes) + 1, Nodes),
      run_op(Node, create_pharmacy, [I, gen_random_name(), gen_random_address()])
    end).

add_facilities(Nodes, Amount) ->
  parallel_create(facilities, Amount,
    fun(I) ->
      Node = lists:nth(I rem length(Nodes) + 1, Nodes),
      run_op(Node, create_facility, [I, gen_random_name(), gen_random_address(), gen_random_type()])
    end).

add_patients(Nodes, Amount) ->
  parallel_create(patients, Amount,
    fun(I) ->
      Node = lists:nth(I rem length(Nodes) + 1, Nodes),
      run_op(Node, create_patient, [I, gen_random_name(), gen_random_address()])
    end).

add_staff(Nodes, Amount) ->
  parallel_create(staff, Amount,
    fun(I) ->
      Node = lists:nth(I rem length(Nodes) + 1, Nodes),
      run_op(Node, create_staff, [I, gen_random_name(), gen_random_address(), gen_random_type()])
    end).

add_prescriptions(_Nodes, 0, _Config) -> ok;
add_prescriptions(Nodes, Amount, Config) when Amount > 0 ->
  io:format("Creating prescriptions...~n"),
  ListPatientIds = gen_sequence(Config#fmkeconfig.numpatients, ?ZIPF_SKEW, Config#fmkeconfig.numprescriptions),
  add_prescription_rec(Nodes, Amount, ListPatientIds, Config, {0, 0}).

add_prescription_rec(_Nodes, 0, _PatientIds, _Config, {Suc, Err}) -> {ok, Suc, Err};
add_prescription_rec(Nodes, PrescriptionId, ListPatientIds, FmkConfig, {Suc, Err}) ->
  [CurrentId | Tail] = ListPatientIds,
  PharmacyId = rand:uniform(FmkConfig#fmkeconfig.numpharmacies),
  PrescriberId = rand:uniform(FmkConfig#fmkeconfig.numstaff),
  Node = lists:nth(PrescriptionId rem length(Nodes) + 1, Nodes),
  Result = run_op(Node, create_prescription, [PrescriptionId, CurrentId, PrescriberId, PharmacyId, gen_random_date(), gen_random_drugs()]),
  {Suc2, Err2} = case Result of
    ok -> {Suc + 1, Err};
    {error, _Reason} -> {Suc, Err + 1}
  end,
  add_prescription_rec(Nodes, PrescriptionId - 1, Tail, FmkConfig, {Suc2, Err2}).

run_op(FmkNode, create_pharmacy, Params) ->
  [_Id, _Name, _Address] = Params,
  run_rpc_op(FmkNode, create_pharmacy, Params);
run_op(FmkNode, create_facility, Params) ->
  [_Id, _Name, _Address, _Type] = Params,
  run_rpc_op(FmkNode, create_facility, Params);
run_op(FmkNode, create_patient, Params) ->
  [_Id, _Name, _Address] = Params,
  run_rpc_op(FmkNode, create_patient, Params);
run_op(FmkNode, create_staff, Params) ->
  [_Id, _Name, _Address, _Speciality] = Params,
  run_rpc_op(FmkNode, create_staff, Params);
run_op(FmkNode, create_prescription, Params) ->
  [_PrescriptionId, _PatientId, _PrescriberId, _PharmacyId, _DatePrescribed, _Drugs] = Params,
  run_rpc_op(FmkNode, create_prescription, Params).

run_rpc_op(FmkNode, Op, Params) ->
  run_rpc_op(FmkNode, Op, Params, 0, ?MAX_RETRIES).

run_rpc_op(_FmkNode, Op, Params, MaxTries, MaxTries) ->
    io:format("Error calling ~p(~p), tried ~p times\n", [Op, Params, MaxTries]),
    {error, exceeded_num_retries};
run_rpc_op(FmkNode, Op, Params, CurrentTry, MaxTries) ->
    case rpc:call(FmkNode, fmke, Op, Params) of
      {badrpc,timeout} ->
        run_rpc_op(FmkNode, Op, Params, CurrentTry + 1, MaxTries);
      {error, Reason} ->
        % io:format("Error ~p in ~p with params ~p\n", [Reason, Op, Params]),
        {error, Reason};
      ok -> ok
     end.

gen_sequence(Size, Skew, SequenceSize) ->
  Bottom = 1 / (lists:foldl(fun(X, Sum) -> Sum + (1 / math:pow(X, Skew)) end, 0, lists:seq(1, Size))),
  lists:map(fun(_X) ->
    zipf_next(Size, Skew, Bottom)
            end, lists:seq(1, SequenceSize)).

zipf_next(Size, Skew, Bottom) ->
  Dice = rand:uniform(),
  next(Dice, Size, Skew, Bottom, 0, 1).

next(Dice, _Size, _Skew, _Bottom, Sum, CurrRank) when Sum >= Dice -> CurrRank - 1;
next(Dice, Size, Skew, Bottom, Sum, CurrRank) ->
  NextRank = CurrRank + 1,
  Sumi = Sum + (Bottom / math:pow(CurrRank, Skew)),
  next(Dice, Size, Skew, Bottom, Sumi, NextRank).

gen_random_drugs() ->
    NumDrugs = rand:uniform(2)+1,
    lists:map(fun(_) -> gen_random_name() end, lists:seq(1,NumDrugs)).

gen_random_name() ->
    gen_random_string(25).

gen_random_address() ->
    gen_random_string(40).

gen_random_type() ->
    gen_random_string(14).

gen_random_date() ->
    gen_random_string(10).

gen_random_string(NumBytes) when NumBytes > 0 ->
    binary_to_list(base64:encode(crypto:strong_rand_bytes(NumBytes))).
