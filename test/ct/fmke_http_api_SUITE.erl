-module(fmke_http_api_SUITE).
-include_lib("common_test/include/ct.hrl").

%%%-------------------------------------------------------------------
%%% Common Test exports
%%%-------------------------------------------------------------------
-export([
    all/0,
    init_per_suite/1,
    end_per_suite/1,
    init_per_group/2,
    end_per_group/2,
    init_per_testcase/2,
    end_per_testcase/2
]).

%%%-------------------------------------------------------------------
%%% Every Common test set to be performed will be called by a function
%%% with the same name as atoms returned in the all/0 function.
%%%-------------------------------------------------------------------
-export([
    event_http_tests/1,
    facility_http_tests/1,
    patient_http_tests/1,
    pharmacy_http_tests/1,
    prescription_http_tests/1,
    staff_http_tests/1,
    treatment_http_tests/1
]).

%%%-------------------------------------------------------------------
%%% Common Test Callbacks
%%%-------------------------------------------------------------------

%% returns a list of all test sets to be executed by Common Test.
all() ->
    [event_http_tests, facility_http_tests, patient_http_tests,
    pharmacy_http_tests, prescription_http_tests, staff_http_tests,
    treatment_http_tests].

%%%-------------------------------------------------------------------
%%% Common Test configuration
%%%-------------------------------------------------------------------

init_per_suite(Config) ->
    application:ensure_all_started(inets),
    Config.

end_per_suite(Config) ->
    Config.

init_per_group(_, Config) ->
    Config.

end_per_group(_, Config) ->
    Config.

init_per_testcase(facility_http_tests, Config) ->
    TabId = ets:new(facilities, [set, protected, named_table]),
    FacilityId = rand:uniform(1000000000000),
    ets:insert(TabId, {facility, FacilityId, "Some Hospital", "Somewhere", "Hospital"}),
    ets:insert(TabId, {updated_facility, FacilityId, "Some Random Hospital", "Somewhere Portugal", "Treatment Facility"}),
    [{table,TabId} | Config];

init_per_testcase(patient_http_tests, Config) ->
    TabId = ets:new(patients, [set, protected, named_table]),
    PatientId = rand:uniform(1000000000000),
    ets:insert(TabId, {patient, PatientId, "Goncalo Tomas", "Somewhere in Portugal"}),
    ets:insert(TabId, {updated_patient, PatientId, "Goncalo P. Tomas", "Caparica, Portugal"}),
    [{table,TabId} | Config];

init_per_testcase(pharmacy_http_tests, Config) ->
    TabId = ets:new(pharmacies, [set, protected, named_table]),
    PharmacyId = rand:uniform(1000000000000),
    ets:insert(TabId, {pharmacy, PharmacyId, "Some Pharmacy", "Somewhere in Portugal"}),
    ets:insert(TabId, {updated_pharmacy, PharmacyId, "Some Random Pharmacy", "Caparica, Portugal"}),
    [{table,TabId} | Config];

init_per_testcase(prescription_http_tests, Config) ->
    TabId = ets:new(prescriptions, [set, protected, named_table]),
    ets:insert(TabId, {patient, 1, "Goncalo Tomas", "Somewhere in Portugal"}),
    ets:insert(TabId, {other_patient, 2, "Goncalo P. Tomas", "Caparica, Portugal"}),
    ets:insert(TabId, {facility, 1, "Some Hospital", "Somewhere", "Hospital"}),
    ets:insert(TabId, {other_facility, 2, "Some Random Hospital", "Somewhere Portugal", "Treatment Facility"}),
    ets:insert(TabId, {pharmacy, 1, "Some Pharmacy", "Somewhere in Portugal"}),
    ets:insert(TabId, {other_pharmacy, 2, "Some Random Pharmacy", "Caparica, Portugal"}),
    ets:insert(TabId, {staff, 1, "Some Doctor", "Somewhere in Portugal", "Traditional Chinese Medicine"}),
    ets:insert(TabId, {other_staff, 2, "Some Random Doctor", "Caparica, Portugal", "weird esoteric kind of medicine"}),
    PrescriptionId = rand:uniform(1000000000000),
    ets:insert(TabId, {prescription, PrescriptionId, 1,1,1, "12/12/2012", "Penicillin, Diazepam"}),
    ets:insert(TabId, {updated_prescription_drugs, PrescriptionId, "Adrenaline"}),
    ets:insert(TabId, {processed_prescription_date, PrescriptionId, "24/12/2012"}),
    ets:insert(TabId, {other_prescription, PrescriptionId+1, 2,2,2, "01/10/2015", "Diazepam"}),
    ets:insert(TabId, {other_updated_prescription_drugs, PrescriptionId+1, "Penicillin, Adrenaline"}),
    ets:insert(TabId, {other_processed_prescription_date, PrescriptionId+1, "01/01/2016"}),
    [{table,TabId} | Config];

init_per_testcase(staff_http_tests, Config) ->
    TabId = ets:new(staff, [set, protected, named_table]),
    StaffId = rand:uniform(1000000000000),
    ets:insert(TabId, {staff, StaffId, "Some Doctor", "Somewhere in Portugal", "Traditional Chinese Medicine"}),
    ets:insert(TabId, {updated_staff, StaffId, "Some Random Doctor", "Caparica, Portugal", "weird esoteric kind of medicine"}),
    [{table,TabId} | Config];

init_per_testcase(_, Config) ->
    Config.


end_per_testcase(facility_http_tests, Config) ->
    ets:delete(?config(table, Config));
end_per_testcase(patient_http_tests, Config) ->
    ets:delete(?config(table, Config));
end_per_testcase(pharmacy_http_tests, Config) ->
    ets:delete(?config(table, Config));
end_per_testcase(prescription_http_tests, Config) ->
    ets:delete(?config(table, Config));
end_per_testcase(staff_http_tests, Config) ->
    ets:delete(?config(table, Config));

end_per_testcase(_, Config) ->
    Config.

event_http_tests(_Config) ->
    % {skip, "Events not implemented in this version of FMKe."}.
    ok.


%%%-------------------------------------------------------------------
%%% facility endpoint tests
%%%-------------------------------------------------------------------


facility_http_tests(Config) ->
    %%TODO add tests with missing/wrong parameters in PUT and POST requests
    get_unexisting_facility(Config),
    add_unexisting_facility(Config),
    get_existing_facility(Config),
    add_existing_facility(Config),
    update_existing_facility(Config),
    update_unexistent_facility(Config),
    get_facility_after_update(Config).

get_unexisting_facility(Config) ->
    TabId = ?config(table, Config),
    [{facility, FacilityId, _, _, _}] = ets:lookup(TabId, facility),
    PropListJson = http_get("/facilities/"++integer_to_list(FacilityId)),
    false = proplists:get_value(<<"success">>,PropListJson),
    <<"not_found">> = proplists:get_value(<<"result">>,PropListJson).

add_unexisting_facility(Config) ->
    TabId = ?config(table, Config),
    [{facility, Id, Name, Address, Type}] = ets:lookup(TabId, facility),
    FacilityProps = build_facility_props([Id, Name, Address, Type]),
    ResponseJson = http_post("/facilities", FacilityProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

get_existing_facility(Config) ->
    TabId = ?config(table, Config),
    [{facility, Id, Name, Address, Type}] = ets:lookup(TabId, facility),
    PropListJson = http_get("/facilities/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    FacilityObject = proplists:get_value(<<"result">>,PropListJson),

    BinaryId = list_to_binary(integer_to_list(Id)),
    BinaryId = proplists:get_value(<<"facilityId">>, FacilityObject),
    BinaryName = list_to_binary(Name),
    BinaryName = proplists:get_value(<<"facilityName">>, FacilityObject),
    BinaryAddress = list_to_binary(Address),
    BinaryAddress = proplists:get_value(<<"facilityAddress">>, FacilityObject),
    BinaryType = list_to_binary(Type),
    BinaryType = proplists:get_value(<<"facilityType">>, FacilityObject).

add_existing_facility(Config) ->
    TabId = ?config(table, Config),
    [{facility, Id, Name, Address, Type}] = ets:lookup(TabId, facility),
    FacilityProps = build_facility_props([Id, Name, Address, Type]),
    ResponseJson = http_post("/facilities", FacilityProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"facility_id_taken">> = proplists:get_value(<<"result">>,ResponseJson).

update_existing_facility(Config) ->
    TabId = ?config(table, Config),
    [{updated_facility, Id, Name, Address, Type}] = ets:lookup(TabId, updated_facility),
    FacilityProps = [{name, Name}, {address, Address}, {type, Type}],
    ResponseJson = http_put("/facilities/" ++ integer_to_list(Id), FacilityProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

update_unexistent_facility(Config) ->
    TabId = ?config(table, Config),
    [{updated_facility, Id, Name, Address, Type}] = ets:lookup(TabId, updated_facility),
    FacilityProps = [{name, Name}, {address, Address}, {type, Type}],
    UnusedId = Id+rand:uniform(100000000),
    ResponseJson = http_put("/facilities/" ++ integer_to_list(UnusedId), FacilityProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"no_such_facility">> = proplists:get_value(<<"result">>,ResponseJson).

get_facility_after_update(Config) ->
    TabId = ?config(table, Config),
    [{updated_facility, Id, Name, Address, Type}] = ets:lookup(TabId, updated_facility),
    PropListJson = http_get("/facilities/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    FacilityObject = proplists:get_value(<<"result">>,PropListJson),

    BinaryId = list_to_binary(integer_to_list(Id)),
    BinaryId = proplists:get_value(<<"facilityId">>, FacilityObject),
    BinaryName = list_to_binary(Name),
    BinaryName = proplists:get_value(<<"facilityName">>, FacilityObject),
    BinaryAddress = list_to_binary(Address),
    BinaryAddress = proplists:get_value(<<"facilityAddress">>, FacilityObject),
    BinaryType = list_to_binary(Type),
    BinaryType = proplists:get_value(<<"facilityType">>, FacilityObject).


%%%-------------------------------------------------------------------
%%% patient endpoint tests
%%%-------------------------------------------------------------------


patient_http_tests(Config) ->
    get_unexisting_patient(Config),
    add_unexisting_patient(Config),
    get_existing_patient(Config),
    add_existing_patient(Config),
    update_existing_patient(Config),
    update_unexistent_patient(Config),
    get_patient_after_update(Config).

get_unexisting_patient(Config) ->
    TabId = ?config(table, Config),
    [{patient, PatientId, _, _}] = ets:lookup(TabId, patient),
    PropListJson = http_get("/patients/"++integer_to_list(PatientId)),
    false = proplists:get_value(<<"success">>,PropListJson),
    <<"not_found">> = proplists:get_value(<<"result">>,PropListJson).

add_unexisting_patient(Config) ->
    TabId = ?config(table, Config),
    [{patient, Id, Name, Address}] = ets:lookup(TabId, patient),
    PatientProps = [{id, Id}, {name, Name}, {address, Address}],
    ResponseJson = http_post("/patients", PatientProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

get_existing_patient(Config) ->
    TabId = ?config(table, Config),
    [{patient, Id, Name, Address}] = ets:lookup(TabId, patient),
    PropListJson = http_get("/patients/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    PatientObject = proplists:get_value(<<"result">>,PropListJson),

    BinaryId = list_to_binary(integer_to_list(Id)),
    BinaryId = proplists:get_value(<<"patientId">>, PatientObject),
    BinaryName = list_to_binary(Name),
    BinaryName = proplists:get_value(<<"patientName">>, PatientObject),
    BinaryAddress = list_to_binary(Address),
    BinaryAddress = proplists:get_value(<<"patientAddress">>, PatientObject),
    [] = proplists:get_value(<<"patientPrescriptions">>, PatientObject).

add_existing_patient(Config) ->
    TabId = ?config(table, Config),
    [{patient, Id, Name, Address}] = ets:lookup(TabId, patient),
    PatientProps = [{id, Id}, {name, Name}, {address, Address}],
    ResponseJson = http_post("/patients", PatientProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"patient_id_taken">> = proplists:get_value(<<"result">>,ResponseJson).

update_existing_patient(Config) ->
    TabId = ?config(table, Config),
    [{updated_patient, Id, Name, Address}] = ets:lookup(TabId, updated_patient),
    PatientProps = [{name, Name}, {address, Address}],
    ResponseJson = http_put("/patients/" ++ integer_to_list(Id), PatientProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

update_unexistent_patient(Config) ->
    TabId = ?config(table, Config),
    [{updated_patient, Id, Name, Address}] = ets:lookup(TabId, updated_patient),
    PatientProps = [{name, Name}, {address, Address}],
    UnusedId = Id+rand:uniform(100000000),
    ResponseJson = http_put("/patients/" ++ integer_to_list(UnusedId), PatientProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"no_such_patient">> = proplists:get_value(<<"result">>,ResponseJson).

get_patient_after_update(Config) ->
    TabId = ?config(table, Config),
    [{updated_patient, Id, Name, Address}] = ets:lookup(TabId, updated_patient),
    PropListJson = http_get("/patients/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    PatientObject = proplists:get_value(<<"result">>,PropListJson),

    BinaryId = list_to_binary(integer_to_list(Id)),
    BinaryId = proplists:get_value(<<"patientId">>, PatientObject),
    BinaryName = list_to_binary(Name),
    BinaryName = proplists:get_value(<<"patientName">>, PatientObject),
    BinaryAddress = list_to_binary(Address),
    BinaryAddress = proplists:get_value(<<"patientAddress">>, PatientObject),
    [] = proplists:get_value(<<"patientPrescriptions">>, PatientObject).


%%%-------------------------------------------------------------------
%%% pharmacy endpoint tests
%%%-------------------------------------------------------------------


pharmacy_http_tests(Config) ->
    get_unexisting_pharmacy(Config),
    add_unexisting_pharmacy(Config),
    get_existing_pharmacy(Config),
    add_existing_pharmacy(Config),
    update_existing_pharmacy(Config),
    update_unexistent_pharmacy(Config),
    get_pharmacy_after_update(Config).

get_unexisting_pharmacy(Config) ->
    TabId = ?config(table, Config),
    [{pharmacy, PharmacyId, _, _}] = ets:lookup(TabId, pharmacy),
    PropListJson = http_get("/pharmacies/"++integer_to_list(PharmacyId)),
    false = proplists:get_value(<<"success">>,PropListJson),
    <<"not_found">> = proplists:get_value(<<"result">>,PropListJson).

add_unexisting_pharmacy(Config) ->
    TabId = ?config(table, Config),
    [{pharmacy, Id, Name, Address}] = ets:lookup(TabId, pharmacy),
    PharmacyProps = [{id, Id}, {name, Name}, {address, Address}],
    ResponseJson = http_post("/pharmacies", PharmacyProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

get_existing_pharmacy(Config) ->
    TabId = ?config(table, Config),
    [{pharmacy, Id, Name, Address}] = ets:lookup(TabId, pharmacy),
    PropListJson = http_get("/pharmacies/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    PharmacyObject = proplists:get_value(<<"result">>,PropListJson),

    BinaryId = list_to_binary(integer_to_list(Id)),
    BinaryId = proplists:get_value(<<"pharmacyId">>, PharmacyObject),
    BinaryName = list_to_binary(Name),
    BinaryName = proplists:get_value(<<"pharmacyName">>, PharmacyObject),
    BinaryAddress = list_to_binary(Address),
    BinaryAddress = proplists:get_value(<<"pharmacyAddress">>, PharmacyObject),
    [] = proplists:get_value(<<"pharmacyPrescriptions">>, PharmacyObject).

add_existing_pharmacy(Config) ->
    TabId = ?config(table, Config),
    [{pharmacy, Id, Name, Address}] = ets:lookup(TabId, pharmacy),
    PharmacyProps = [{id, Id}, {name, Name}, {address, Address}],
    ResponseJson = http_post("/pharmacies", PharmacyProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"pharmacy_id_taken">> = proplists:get_value(<<"result">>,ResponseJson).

update_existing_pharmacy(Config) ->
    TabId = ?config(table, Config),
    [{updated_pharmacy, Id, Name, Address}] = ets:lookup(TabId, updated_pharmacy),
    PharmacyProps = [{name, Name}, {address, Address}],
    ResponseJson = http_put("/pharmacies/" ++ integer_to_list(Id), PharmacyProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

update_unexistent_pharmacy(Config) ->
    TabId = ?config(table, Config),
    [{updated_pharmacy, Id, Name, Address}] = ets:lookup(TabId, updated_pharmacy),
    PharmacyProps = [{name, Name}, {address, Address}],
    UnusedId = Id+rand:uniform(100000000),
    ResponseJson = http_put("/pharmacies/" ++ integer_to_list(UnusedId), PharmacyProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"no_such_pharmacy">> = proplists:get_value(<<"result">>,ResponseJson).

get_pharmacy_after_update(Config) ->
    TabId = ?config(table, Config),
    [{updated_pharmacy, Id, Name, Address}] = ets:lookup(TabId, updated_pharmacy),
    PropListJson = http_get("/pharmacies/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    PharmacyObject = proplists:get_value(<<"result">>,PropListJson),

    BinaryId = list_to_binary(integer_to_list(Id)),
    BinaryId = proplists:get_value(<<"pharmacyId">>, PharmacyObject),
    BinaryName = list_to_binary(Name),
    BinaryName = proplists:get_value(<<"pharmacyName">>, PharmacyObject),
    BinaryAddress = list_to_binary(Address),
    BinaryAddress = proplists:get_value(<<"pharmacyAddress">>, PharmacyObject),
    [] = proplists:get_value(<<"pharmacyPrescriptions">>, PharmacyObject).


%%%-------------------------------------------------------------------
%%% prescription endpoint tests
%%%-------------------------------------------------------------------


prescription_http_tests(Config) ->
    add_required_entities(Config),
    get_unexisting_prescription(Config),
    process_unexisting_prescription(Config),
    add_medication_to_unexisting_prescription(Config),
    add_unexisting_prescription(Config),
    get_existing_prescription(Config),
    add_existing_prescription(Config),
    update_prescription_medication(Config),
    process_existing_prescription(Config),
    add_medication_to_processed_prescription(Config),
    process_already_processed_prescription(Config),
    get_prescription_after_updates(Config).

add_required_entities(Config) ->
    TabId = ?config(table, Config),
    [{facility, FacId1, FacName1, FacAddr1, FacType1}] = ets:lookup(TabId, facility),
    [{other_facility, FacId2, FacName2, FacAddr2, FacType2}] = ets:lookup(TabId, other_facility),
    [{patient, PatId1, PatName1, PatAddr1}] = ets:lookup(TabId, patient),
    [{other_patient, PatId2, PatName2, PatAddr2}] = ets:lookup(TabId, other_patient),
    [{pharmacy, PharmId1, PharmName1, PharmAddress1}] = ets:lookup(TabId, pharmacy),
    [{other_pharmacy, PharmId2, PharmName2, PharmAddress2}] = ets:lookup(TabId, other_pharmacy),
    [{staff, StaId1, StaName1, StaAddr1, StaSpec1}] = ets:lookup(TabId, staff),
    [{other_staff, StaId2, StaName2, StaAddr2, StaSpec2}] = ets:lookup(TabId, other_staff),

    FacilityProps1 = build_facility_props([FacId1, FacName1, FacAddr1, FacType1]),
    FacilityProps2 = build_facility_props([FacId2, FacName2, FacAddr2, FacType2]),
    PatientProps1 = build_patient_props([PatId1, PatName1, PatAddr1]),
    PatientProps2 = build_patient_props([PatId2, PatName2, PatAddr2]),
    PharmacyProps1 = build_pharmacy_props([PharmId1, PharmName1, PharmAddress1]),
    PharmacyProps2 = build_pharmacy_props([PharmId2, PharmName2, PharmAddress2]),
    StaffProps1 = build_staff_props([StaId1, StaName1, StaAddr1, StaSpec1]),
    StaffProps2 = build_staff_props([StaId2, StaName2, StaAddr2, StaSpec2]),

    successful_http_post("/facilities/"++integer_to_list(FacId1), FacilityProps1),
    successful_http_post("/facilities/"++integer_to_list(FacId2), FacilityProps2),
    successful_http_post("/patients/"++integer_to_list(PatId1), PatientProps1),
    successful_http_post("/patients/"++integer_to_list(PatId2), PatientProps2),
    successful_http_post("/pharmacies/"++integer_to_list(PharmId1), PharmacyProps1),
    successful_http_post("/pharmacies/"++integer_to_list(PharmId2), PharmacyProps2),
    successful_http_post("/staff/"++integer_to_list(StaId1), StaffProps1),
    successful_http_post("/staff/"++integer_to_list(StaId2), StaffProps2).

get_unexisting_prescription(Config) ->
    TabId = ?config(table, Config),
    [{prescription, Id, _, _, _, _, _}] = ets:lookup(TabId, prescription),
    PropListJson = http_get("/prescriptions/"++integer_to_list(Id)),
    false = proplists:get_value(<<"success">>,PropListJson),
    <<"not_found">> = proplists:get_value(<<"result">>,PropListJson).

process_unexisting_prescription(Config) ->
    TabId = ?config(table, Config),
    [{prescription, Id, _, _, _, _, _}] = ets:lookup(TabId, prescription),
    Properties = [{date_processed, "14/08/2017"}],
    PropListJson = http_put("/prescriptions/"++integer_to_list(Id-1),Properties),
    false = proplists:get_value(<<"success">>,PropListJson),
    <<"no_such_prescription">> = proplists:get_value(<<"result">>,PropListJson).

add_medication_to_unexisting_prescription(Config) ->
    TabId = ?config(table, Config),
    [{prescription, Id, _, _, _, _, _}] = ets:lookup(TabId, prescription),
    Properties = [{drugs, "RandomDrug1, RandomDrug2, RandomDrug3"}],
    PropListJson = http_put("/prescriptions/"++integer_to_list(Id-1),Properties),
    false = proplists:get_value(<<"success">>,PropListJson),
    <<"no_such_prescription">> = proplists:get_value(<<"result">>,PropListJson).

add_unexisting_prescription(Config) ->
    TabId = ?config(table, Config),
    [{prescription, Id, PatId, PrescId, PharmId, DatePresc, Drugs}] = ets:lookup(TabId, prescription),
    PrescriptionProps = build_prescription_props([Id, PatId, PrescId, PharmId, DatePresc, Drugs]),
    ResponseJson = http_post("/prescriptions", PrescriptionProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

get_existing_prescription(Config) ->
    TabId = ?config(table, Config),
    [{prescription, Id, PatId, PrescId, PharmId, DatePresc, Drugs}] = ets:lookup(TabId, prescription),
    PropListJson = http_get("/prescriptions/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    PrescriptionObject = proplists:get_value(<<"result">>,PropListJson),
    %% check for prescription field values
    BinId = list_to_binary(integer_to_list(Id)),
    BinPatId = list_to_binary(integer_to_list(PatId)),
    BinPrescId = list_to_binary(integer_to_list(PrescId)),
    BinPharmId = list_to_binary(integer_to_list(PharmId)),
    BinDatePresc = list_to_binary(DatePresc),

    BinId = proplists:get_value(<<"prescriptionId">>, PrescriptionObject),
    BinPatId = proplists:get_value(<<"prescriptionPatientId">>, PrescriptionObject),
    BinPrescId = proplists:get_value(<<"prescriptionPrescriberId">>, PrescriptionObject),
    BinPharmId = proplists:get_value(<<"prescriptionPharmacyId">>, PrescriptionObject),
    BinDatePresc = proplists:get_value(<<"prescriptionDatePrescribed">>, PrescriptionObject),
    <<"prescription_not_processed">> = proplists:get_value(<<"prescriptionIsProcessed">>, PrescriptionObject),
    <<"undefined">> = proplists:get_value(<<"prescriptionDateProcessed">>, PrescriptionObject),
    BinDrugs = lists:sort([list_to_binary(X) || X <- fmke_http_utils:parse_csv_string(drugs,Drugs)]),
    BinDrugs = lists:sort(proplists:get_value(<<"prescriptionDrugs">>, PrescriptionObject)),

    %% check for same prescription inside patient, pharmacy and staff
    PrescriptionKey = gen_key(prescription, Id),
    PatientReqResult = http_get("/patients/"++integer_to_list(PatId)),
    true = proplists:get_value(<<"success">>,PatientReqResult),
    PatientObject = proplists:get_value(<<"result">>,PatientReqResult),
    PatientPrescriptions = proplists:get_value(<<"patientPrescriptions">>, PatientObject),
    true = lists:member(PrescriptionObject, PatientPrescriptions)
            orelse lists:member(PrescriptionKey, PatientPrescriptions),

    PharmacyReqResult = http_get("/pharmacies/"++integer_to_list(PharmId)),
    true = proplists:get_value(<<"success">>,PharmacyReqResult),
    PharmacyObject = proplists:get_value(<<"result">>,PharmacyReqResult),
    PharmacyPrescriptions = proplists:get_value(<<"pharmacyPrescriptions">>, PharmacyObject),
    true = lists:member(PrescriptionObject, PharmacyPrescriptions)
            orelse lists:member(PrescriptionKey, PharmacyPrescriptions),

    StaffReqResult = http_get("/staff/"++integer_to_list(PrescId)),
    true = proplists:get_value(<<"success">>,StaffReqResult),
    StaffObject = proplists:get_value(<<"result">>,StaffReqResult),
    StaffPrescriptions = proplists:get_value(<<"staffPrescriptions">>, StaffObject),
    true = lists:member(PrescriptionObject, StaffPrescriptions)
            orelse lists:member(PrescriptionKey, StaffPrescriptions).

add_existing_prescription(Config) ->
    TabId = ?config(table, Config),
    [{prescription, Id, PatId, PrescId, PharmId, DatePresc, Drugs}] = ets:lookup(TabId, prescription),
    PrescriptionProps = build_prescription_props([Id, PatId, PrescId, PharmId, DatePresc, Drugs]),
    ResponseJson = http_post("/prescriptions", PrescriptionProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"prescription_id_taken">> = proplists:get_value(<<"result">>,ResponseJson).

update_prescription_medication(Config) ->
    TabId = ?config(table, Config),
    [{updated_prescription_drugs, Id, Drugs}] = ets:lookup(TabId, updated_prescription_drugs),
    PrescriptionProps = [{drugs, Drugs}],
    ResponseJson = http_put("/prescriptions/" ++ integer_to_list(Id), PrescriptionProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

process_existing_prescription(Config) ->
    TabId = ?config(table, Config),
    [{processed_prescription_date, Id, Date}] = ets:lookup(TabId, processed_prescription_date),
    PrescriptionProps = [{date_processed, Date}],
    ResponseJson = http_put("/prescriptions/" ++ integer_to_list(Id), PrescriptionProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

add_medication_to_processed_prescription(Config) ->
    TabId = ?config(table, Config),
    [{updated_prescription_drugs, Id, Drugs}] = ets:lookup(TabId, updated_prescription_drugs),
    PrescriptionProps = [{drugs, Drugs}],
    ResponseJson = http_put("/prescriptions/" ++ integer_to_list(Id), PrescriptionProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"prescription_already_processed">> = proplists:get_value(<<"result">>,ResponseJson).

process_already_processed_prescription(Config) ->
    TabId = ?config(table, Config),
    [{processed_prescription_date, Id, Date}] = ets:lookup(TabId, processed_prescription_date),
    PrescriptionProps = [{date_processed, Date}],
    ResponseJson = http_put("/prescriptions/" ++ integer_to_list(Id), PrescriptionProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"prescription_already_processed">> = proplists:get_value(<<"result">>,ResponseJson).

get_prescription_after_updates(Config) ->
    TabId = ?config(table, Config),
    [{prescription, Id, PatId, PrescId, PharmId, DatePresc, Drugs}] = ets:lookup(TabId, prescription),
    [{processed_prescription_date, Id, DateProc}] = ets:lookup(TabId, processed_prescription_date),
    [{updated_prescription_drugs, Id, AdditionalDrugs}] = ets:lookup(TabId, updated_prescription_drugs),
    PropListJson = http_get("/prescriptions/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    PrescriptionObject = proplists:get_value(<<"result">>,PropListJson),
    %% check for prescription field values
    BinId = list_to_binary(integer_to_list(Id)),
    BinPatId = list_to_binary(integer_to_list(PatId)),
    BinPrescId = list_to_binary(integer_to_list(PrescId)),
    BinPharmId = list_to_binary(integer_to_list(PharmId)),
    BinDatePresc = list_to_binary(DatePresc),
    BinDateProc = list_to_binary(DateProc),

    BinId = proplists:get_value(<<"prescriptionId">>, PrescriptionObject),
    BinPatId = proplists:get_value(<<"prescriptionPatientId">>, PrescriptionObject),
    BinPrescId = proplists:get_value(<<"prescriptionPrescriberId">>, PrescriptionObject),
    BinPharmId = proplists:get_value(<<"prescriptionPharmacyId">>, PrescriptionObject),
    BinDatePresc = proplists:get_value(<<"prescriptionDatePrescribed">>, PrescriptionObject),
    <<"prescription_processed">> = proplists:get_value(<<"prescriptionIsProcessed">>, PrescriptionObject),
    BinDateProc = proplists:get_value(<<"prescriptionDateProcessed">>, PrescriptionObject),
    MergedDrugs = lists:append(fmke_http_utils:parse_csv_string(drugs,Drugs),
                                fmke_http_utils:parse_csv_string(drugs,AdditionalDrugs)),
    BinDrugs = lists:sort([list_to_binary(X) || X <- MergedDrugs]),
    BinDrugs = lists:sort(proplists:get_value(<<"prescriptionDrugs">>, PrescriptionObject)),

    %% check for same prescription inside patient, pharmacy and staff
    PrescriptionKey = gen_key(prescription, Id),
    PatientReqResult = http_get("/patients/"++integer_to_list(PatId)),
    true = proplists:get_value(<<"success">>,PatientReqResult),
    PatientObject = proplists:get_value(<<"result">>,PatientReqResult),
    PatientPrescriptions = proplists:get_value(<<"patientPrescriptions">>, PatientObject),
    true = lists:member(PrescriptionObject, PatientPrescriptions)
            orelse lists:member(PrescriptionKey, PatientPrescriptions),

    PharmacyReqResult = http_get("/pharmacies/"++integer_to_list(PharmId)),
    true = proplists:get_value(<<"success">>,PharmacyReqResult),
    PharmacyObject = proplists:get_value(<<"result">>,PharmacyReqResult),
    PharmacyPrescriptions = proplists:get_value(<<"pharmacyPrescriptions">>, PharmacyObject),
    true = lists:member(PrescriptionObject, PharmacyPrescriptions)
            orelse lists:member(PrescriptionKey, PharmacyPrescriptions),

    StaffReqResult = http_get("/staff/"++integer_to_list(PrescId)),
    true = proplists:get_value(<<"success">>,StaffReqResult),
    StaffObject = proplists:get_value(<<"result">>,StaffReqResult),
    StaffPrescriptions = proplists:get_value(<<"staffPrescriptions">>, StaffObject),
    true = lists:member(PrescriptionObject, StaffPrescriptions)
            orelse lists:member(PrescriptionKey, StaffPrescriptions).


%%%-------------------------------------------------------------------
%%% staff endpoint tests
%%%-------------------------------------------------------------------


staff_http_tests(Config) ->
    %%TODO test with missing parameters in PUT and POST requests
    get_unexisting_staff(Config),
    add_unexisting_staff(Config),
    get_existing_staff(Config),
    add_existing_staff(Config),
    update_existing_staff(Config),
    update_unexistent_staff(Config),
    get_staff_after_update(Config).

get_unexisting_staff(Config) ->
    TabId = ?config(table, Config),
    [{staff, StaffId, _, _, _}] = ets:lookup(TabId, staff),
    PropListJson = http_get("/staff/"++integer_to_list(StaffId)),
    false = proplists:get_value(<<"success">>,PropListJson),
    <<"not_found">> = proplists:get_value(<<"result">>,PropListJson).

add_unexisting_staff(Config) ->
    TabId = ?config(table, Config),
    [{staff, Id, Name, Address, Speciality}] = ets:lookup(TabId, staff),
    StaffProps = build_staff_props([Id, Name, Address, Speciality]),
    ResponseJson = http_post("/staff", StaffProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

get_existing_staff(Config) ->
    TabId = ?config(table, Config),
    [{staff, Id, Name, Address, Speciality}] = ets:lookup(TabId, staff),
    PropListJson = http_get("/staff/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    StaffObject = proplists:get_value(<<"result">>,PropListJson),

    BinaryId = list_to_binary(integer_to_list(Id)),
    BinaryId = proplists:get_value(<<"staffId">>, StaffObject),
    BinaryName = list_to_binary(Name),
    BinaryName = proplists:get_value(<<"staffName">>, StaffObject),
    BinaryAddress = list_to_binary(Address),
    BinaryAddress = proplists:get_value(<<"staffAddress">>, StaffObject),
    BinarySpeciality = list_to_binary(Speciality),
    BinarySpeciality = proplists:get_value(<<"staffSpeciality">>, StaffObject),
    [] = proplists:get_value(<<"staffPrescriptions">>, StaffObject).

add_existing_staff(Config) ->
    TabId = ?config(table, Config),
    [{staff, Id, Name, Address, Speciality}] = ets:lookup(TabId, staff),
    StaffProps = build_staff_props([Id, Name, Address, Speciality]),
    ResponseJson = http_post("/staff", StaffProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"staff_id_taken">> = proplists:get_value(<<"result">>,ResponseJson).

update_existing_staff(Config) ->
    TabId = ?config(table, Config),
    [{updated_staff, Id, Name, Address, Speciality}] = ets:lookup(TabId, updated_staff),
    StaffProps = [{name, Name}, {address, Address}, {speciality, Speciality}],
    ResponseJson = http_put("/staff/" ++ integer_to_list(Id), StaffProps),
    true = proplists:get_value(<<"success">>,ResponseJson),
    <<"ok">> = proplists:get_value(<<"result">>,ResponseJson).

update_unexistent_staff(Config) ->
    TabId = ?config(table, Config),
    [{updated_staff, Id, Name, Address, Speciality}] = ets:lookup(TabId, updated_staff),
    StaffProps = [{name, Name}, {address, Address}, {speciality, Speciality}],
    UnusedId = Id+rand:uniform(100000000),
    ResponseJson = http_put("/staff/" ++ integer_to_list(UnusedId), StaffProps),
    false = proplists:get_value(<<"success">>,ResponseJson),
    <<"no_such_staff">> = proplists:get_value(<<"result">>,ResponseJson).

get_staff_after_update(Config) ->
    TabId = ?config(table, Config),
    [{updated_staff, Id, Name, Address, Speciality}] = ets:lookup(TabId, updated_staff),
    PropListJson = http_get("/staff/"++integer_to_list(Id)),
    true = proplists:get_value(<<"success">>,PropListJson),
    StaffObject = proplists:get_value(<<"result">>,PropListJson),

    BinaryId = list_to_binary(integer_to_list(Id)),
    BinaryId = proplists:get_value(<<"staffId">>, StaffObject),
    BinaryName = list_to_binary(Name),
    BinaryName = proplists:get_value(<<"staffName">>, StaffObject),
    BinaryAddress = list_to_binary(Address),
    BinaryAddress = proplists:get_value(<<"staffAddress">>, StaffObject),
    BinarySpeciality = list_to_binary(Speciality),
    BinarySpeciality = proplists:get_value(<<"staffSpeciality">>, StaffObject).


%%%-------------------------------------------------------------------
%%% treatment endpoint tests
%%%-------------------------------------------------------------------


treatment_http_tests(_Config) ->
    % {skip, "Treatments not implemented in this version of FMKe."}.
    ok.


%%%-------------------------------------------------------------------
%%% Auxiliary functions
%%%-------------------------------------------------------------------

successful_http_post(Url, Data)->
    JsonResponse = http_post(Url, Data),
    true = proplists:get_value(<<"success">>,JsonResponse).

http_get(Url) ->
    FullUrl = "http://localhost:9090" ++ Url,
    Headers = [],
    HttpOptions = [],
    Options = [{sync, true}],
    {ok, {{_, 200, _}, _, Body}} = httpc:request(get, {FullUrl, Headers}, HttpOptions, Options),
    jsx:decode(list_to_binary(Body)).

http_post(Url, Data) ->
    http_req_w_body(post, Url, Data).

http_put(Url, Data) ->
    http_req_w_body(put, Url, Data).

http_req_w_body(Method, Url, Data) ->
    FullUrl = "http://localhost:9090" ++ Url,
    Headers = [],
    HttpOptions = [],
    Options = [{sync, true}],
    Json = jsx:encode(Data),
    {ok, {{_, 200, _}, _, Body}} = httpc:request(Method, {FullUrl, Headers, "application/json", Json}, HttpOptions, Options),
    jsx:decode(list_to_binary(Body)).

build_facility_props(PropValues) ->
    build_generic_props([id,name,address,type], PropValues).

build_patient_props(PropValues) ->
    build_generic_props([id,name,address], PropValues).

build_pharmacy_props(PropValues) ->
    build_generic_props([id,name,address], PropValues).

build_prescription_props(PropValues) ->
    build_generic_props([id, patient_id, prescriber_id, pharmacy_id, date_prescribed, drugs], PropValues).

build_staff_props(PropValues) ->
    build_generic_props([id,name,address,speciality], PropValues).

build_generic_props(List1, List2) ->
    build_generic_props(List1, List2, []).

build_generic_props([], [], Accum) ->
    Accum;
build_generic_props([H1|T1], [H2|T2], Accum) ->
    build_generic_props(T1, T2, lists:append(Accum, [{H1,H2}])).

gen_key(Entity,Id) ->
    list_to_binary(lists:flatten(io_lib:format("~p_~p",[Entity,Id]))).
