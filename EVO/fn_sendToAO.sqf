private ["_currentTarget","_type","_init","_grp","_spawnPos","_null","_spawnPos2","_veh","_ret","_transport","_transGrp","_goTo","_heli","_heliGrp","_tank","_lz"];
//Declare variables and parameters
_currentTarget = [_this, 0, objNull] call BIS_fnc_param;
_type = [_this, 1, "error"] call BIS_fnc_param;
_init = [_this, 2, false] call BIS_fnc_param;
fnc_randomPosition = { 
    params ["_center"]; 
    _radius = 500; 
    _angle = random 360; 
    _distance2D = random _radius; 
    _position = [_center select 0, _center select 1, 0] vectorAdd [_distance2D * sin _angle, _distance2D * cos _angle, 0]; 
    _position set [2, getTerrainHeightASL _position]; 
    _position 
};
fnc_pickLandTransport = { 
    params ["_grp"]; 
	_group_size = count units _grp;
	_availTrans = [];
    {
		_transport_classname = _x;
		_transport_capacity = getNumber (configFile >> "CfgVehicles" >> _transport_classname >> "transportSoldier");
		if (_transport_capacity >= _group_size) then {_availTrans pushBack _transport_classname};
	} forEach EVO_opforGroundTrans;
	_ret = _availTrans call bis_fnc_selectRandom;
	_ret
};
fnc_pickAirTransport = { 
    params ["_grp"]; 
	_group_size = count units _grp;
	_availTrans = [];
    {
		_transport_classname = _x;
		_transport_capacity = getNumber (configFile >> "CfgVehicles" >> _transport_classname >> "transportSoldier");
		if (_transport_capacity >= _group_size) then {_availTrans pushBack _transport_classname};
	} forEach EVO_opforAirTrans;
	_ret = _availTrans call bis_fnc_selectRandom;
	_ret
};
//If we started too late and the AO is over, error out
if (!RTonline && !(_currentTarget == currentTarget)) exitWith {["EVO_fnc_sendToAO called after AO change."] call BIS_fnc_error};
_grp = grpNull;
//_spawnPos = position (targetLocations select (targetCounter + 1));
_spawnPos = getPos server;
//Decide if we are workign with infantry or armor
switch (_type) do {
    case "infantry": {
		//working with infantry
    	if (_init) then {
			//if were starting the AO, spawn everything already there at a safe loc
    		_spawnPos = [position currentTarget, 10, 500, 10, 0, 2, 0, [], [getPos server, getPos server]] call BIS_fnc_findSafePos;
    	} else {
			//if the ao is already started, spawn everything at a safe loc
    		//_spawnPos = getPos server;
			_spawnPos = [position server] call fnc_randomPosition; 
    	};
		//spawn the grp
		_grp = [_spawnPos, EAST, (EVO_opforInfantry call BIS_fnc_selectRandom)] call EVO_fnc_spawnGroup;
		{
			if (HCconnected) then {
				//handoff to HC if needed
				handle = [_x] call EVO_fnc_sendToHC;
			};
			//add all units to currentAOUnits array for safe keeping
			currentAOunits pushBack _x;
			publicVariable "currentAOunits";
			//remove from current AO units on death
			_x AddMPEventHandler ["mpkilled", {
				currentAOunits = currentAOunits - [_this select 1];
				publicVariable "currentAOunits";
			}];
		} forEach units _grp;
		if (_init) then {
				//if starting ao then decide weather to hunker down or patrol. more patrol than defend
				if ([true, true, true, false, false, false, false, false, false, false, false] call bis_fnc_selectRandom) then {
					[_grp, getmarkerpos currentTargetMarkerName, 300] call CBA_fnc_taskDefend;
				} else {
					[_grp, getmarkerpos currentTargetMarkerName, 300] call CBA_fnc_taskPatrol;
				};
		} else {
			//were not starting an ao, so we need to deliver units from the next ao to the current ao
			[_grp] spawn {
				_grp = _this select 0;
				if ([true, true, false] call bis_fnc_selectRandom) then {
					//insert via land
					//_spawnPos2 = getPos server;
					_spawnPos2 = [position server] call fnc_randomPosition; 
					//spawn the vehicle and declare trans var
					_transClass = _grp call fnc_pickLandTransport;
					_ret = [_spawnPos2, (floor (random 360)), _transClass, EAST] call EVO_fnc_spawnvehicle;
				    _transport = _ret select 0;
				    _transGrp = _ret select 2;
					_transGrp setVariable ["Vcm_Disable",true];
					//find nearest road and put the transport on it
					_transport allowDamage false;
				    _roads = (position (targetLocations select (targetCounter + 1))) nearRoads 500;
				    _nearestRoad = _roads call BIS_fnc_selectRandom;
				    _transport setPos getPos _nearestRoad;
					_transport setDir (getDir _nearestRoad);
					sleep 1;
					_transport allowDamage true;
					{
						if (HCconnected) then {
							//send to HC if available
							handle = [_x] call EVO_fnc_sendToHC;
						};
						_x AddMPEventHandler ["mpkilled", {
							currentAOunits = currentAOunits - [_this select 1];
							publicVariable "currentAOunits";
						}];
					} forEach units _grp;
					//assign groups as cargo of trans
					{
				    	_x assignAsCargo _transport;
				    	_x moveInCargo _transport;
				    } forEach units _grp;
					//send trans into AO and deliver units
				    //_goTo = position currentTarget;
					_roads = (position currentTarget) nearRoads 350;
				    _nearestRoad = _roads call BIS_fnc_selectRandom;
				    _goTo = position _nearestRoad;
					_transport setVariable ["evo_hit", false, true];
					_transport addEventHandler ["Hit", {
						params ["_unit", "_source", "_damage", "_instigator"];
						if (side _source == WEST) then {
							_unit setVariable ["evo_hit", true, true];
							_unit removeEventHandler [_thisEvent, _thisEventHandler];
						};
					}];
					_transport domove _goTo;
				    waitUntil { sleep 1; isNull _transport || _transport distance2D _goTo < 100 || not alive _transport || _transport getVariable "evo_hit"};
				    doStop _transport;
				    {
				    	unassignVehicle  _x;
				    } forEach units _grp;
				    _grp leaveVehicle _transport;
				    waitUntil { sleep 1;count crew _transport == count units _transGrp || isNull _transport || !alive _transport};

						if ([true, true, true, false, false, false, false, false, false, false, false] call bis_fnc_selectRandom) then {
							[this, getmarkerpos currentTargetMarkerName, 300] call CBA_fnc_taskDefend;
						} else {
							[_grp, getmarkerpos currentTargetMarkerName, 300] call CBA_fnc_taskPatrol;
						};

				    doStop _transport;
				    _transport doMove (position (targetLocations select (targetCounter + 1)));
				    handle = [_transport] spawn {
				    	_spawnPos = _this select 1;
				    	_transport = _this select 0;
				    	waitUntil { sleep 1;(_transport distance2D (position (targetLocations select (targetCounter + 1)))) < 100 || isNull _transport || !alive _transport };
				    	deleteVehicleCrew _transport;
				    	deleteVehicle _transport;
					};
				} else {
					//insert via air
					_spawnPos2 = [position (targetLocations select (targetCounter + 1))] call fnc_randomPosition; 
					_transClass = _grp call fnc_pickAirTransport;
				    _ret = [_spawnPos2, (floor (random 360)), _transClass, EAST] call EVO_fnc_spawnvehicle;
				    _heli = _ret select 0;
				    _heliGrp = _ret select 2;
					_heliGrp setVariable ["Vcm_Disable",true];
				    {
						if (HCconnected) then {
							handle = [_x] call EVO_fnc_sendToHC;
						};
					} forEach units _heliGrp;
				    {
				    	_x assignAsCargo _heli;
				    	_x moveInCargo _heli;
				    } forEach units _grp;
				    if ([true, false, false] call bis_fnc_selectRandom) then {
				    	//paradrop
					    _goTo = [position currentTarget] call fnc_randomPosition;
					    _heli doMove _goTo;
					    _heli flyInHeight 150;
					    waitUntil { sleep 1; _heli distance2D _goTo < 100 || isNull _heli || !alive _heli};
					    handle = [_heli] spawn EVO_fnc_paradrop;
					    //doStop _heli;
					    _heli doMove getPos server;
					    handle = [_heli] spawn {
					    	_heli = _this select 0;
					    	waitUntil { sleep 1; (_heli distance2D server) < 1000 || {_x distance2D _heli < 1500} count allPlayers < 1 || isNull _heli || !alive _heli};
					    	deleteVehicleCrew _heli;
					    	deleteVehicle _heli;
						};

			    		[_grp, getmarkerpos currentTargetMarkerName, 300] call CBA_fnc_taskPatrol;

					} else {
						//land
						_lz = current_landing_zones call bis_fnc_selectRandom;
						_goTo = position _lz;
						_heli flyInHeight 25;
						[group _heli, _goTo, _lz] spawn BIS_fnc_wpLand;
					    waitUntil { sleep 1;(_heli distance2D _goTo < 100) || !alive _heli || isNull _heli};
					    {
					    	unassignVehicle  _x;
					    	doGetOut _x
					    } forEach units _grp;
					    _grp leaveVehicle _heli;
					    waitUntil { sleep 1;count crew _heli == count units _heliGrp || !alive _heli || isNull _heli};
					    _heli doMove getPos server;
					    handle = [_heli] spawn {
					    	_heli = _this select 0;
					    	waitUntil { sleep 1; (_heli distance2D server) < 1000 || {_x distance2D _heli < 1500} count allPlayers < 1 || isNull _heli || !alive _heli};
					    	deleteVehicleCrew _heli;
					    	deleteVehicle _heli;
						};

			    		[_grp, getmarkerpos currentTargetMarkerName, 300] call CBA_fnc_taskPatrol;

					};
				};
			};
		};
    };
	case "radio": {
		//working with infantry
    	if (_init) then {
			//if were starting the AO, spawn everything already there at a safe loc
    		_spawnPos = [getPos currentTargetRT, 10, 300, 10, 0, 2, 0, [], [getPos server, getPos server]] call BIS_fnc_findSafePos;
    	} else {
			//if the ao is already started, spawn everything at a safe loc at the next AO
    		_spawnPos = getPos server;
    	};
		//spawn the grp
		_grp = [_spawnPos, EAST, (EVO_opforInfantry call BIS_fnc_selectRandom)] call EVO_fnc_spawnGroup;
		{
			if (HCconnected) then {
				//handoff to HC if needed
				handle = [_x] call EVO_fnc_sendToHC;
			};
			//add all units to currentAOUnits array for safe keeping
			currentAOunits pushBack _x;
			publicVariable "currentAOunits";
			//remove from current AO units on death
			_x AddMPEventHandler ["mpkilled", {
				currentAOunits = currentAOunits - [_this select 1];
				publicVariable "currentAOunits";
			}];
		} forEach units _grp;
		if (_init) then {
				//if starting ao then decide weather to hunker down or patrol. more patrol than defend
				if ([true, true, true, false, false, false, false, false, false, false, false] call bis_fnc_selectRandom) then {
					[_grp, getPos currentTargetRT, 100] call CBA_fnc_taskDefend;
				} else {
					[_grp, getPos currentTargetRT, 100] call CBA_fnc_taskPatrol;
				};
		} else {
			//were not starting an ao, so we need to deliver units from the next ao to the current ao
			[_grp] spawn {
				_grp = _this select 0;
				if ([true, true, true, true, false] call bis_fnc_selectRandom) then {
					//insert via land
					//spawn pos near grp
					_spawnPos2 = getPos server;
					//spawn the vehicle and declare trans var
					_transClass = _grp call fnc_pickLandTransport;
					_ret = [_spawnPos2, (floor (random 360)), _transClass, EAST] call EVO_fnc_spawnvehicle;
				    _transport = _ret select 0;
				    _transGrp = _ret select 2;
					_transGrp setVariable ["Vcm_Disable",true];
					//find nearest road and put the transport on it
				    _roads = (position (targetLocations select (targetCounter + 1))) nearRoads 500;
				    _nearestRoad = _roads call BIS_fnc_selectRandom;
				    _transport setPos getPos _nearestRoad;
					_transport setDir getDir _nearestRoad;
					{
						if (HCconnected) then {
							//send to HC if available
							handle = [_x] call EVO_fnc_sendToHC;
						};
						_x AddMPEventHandler ["mpkilled", {
							currentAOunits = currentAOunits - [_this select 1];
							publicVariable "currentAOunits";
						}];
					} forEach units _grp;
					//assign groups as cargo of trans
					{
				    	_x assignAsCargo _transport;
				    	_x moveInCargo _transport;
				    } forEach units _grp;
					//send trans into AO and deliver units
				    _goTo = getPos currentTargetRT;
				    _transport doMove _goTo;
					_transport setVariable ["evo_hit", false, true];
					_transport addEventHandler ["Hit", {
						params ["_unit", "_source", "_damage", "_instigator"];
						if (side _source == WEST) then {
							_unit setVariable ["evo_hit", true, true];
							_unit removeEventHandler [_thisEvent, _thisEventHandler];
						};
					}];
				    waitUntil { sleep 1; _transport distance2D (position currentTarget) < 500 || isNull _transport || !alive _transport || _transport getVariable "evo_hit"};
				    doStop _transport;
				    {
				    	unassignVehicle  _x;
				    } forEach units _grp;
				    _grp leaveVehicle _transport;
						if ([true, true, true, false, false, false, false, false, false, false, false] call bis_fnc_selectRandom) then {
							[_grp, getPos currentTargetRT, 100] call CBA_fnc_taskDefend;
						} else {
							[_grp, getPos currentTargetRT, 100] call CBA_fnc_taskPatrol;
						};
				    _transport doMove _spawnPos2;
				    handle = [_transport, _spawnPos2] spawn {
				    	_spawnPos = _this select 1;
				    	_transport = _this select 0;
					    	waitUntil { sleep 1; {_x distance2D _transport < 1500} count allPlayers < 1 || !alive _transport || isNull _transport};
				    	{
				    		deleteVehicle _x;
				    	} forEach units group driver _transport;
				    	deleteVehicle _transport;
					};
				} else {
					//insert via air
					_spawnPos2 = [position (targetLocations select (targetCounter + 1))] call fnc_randomPosition; 
					_spawnPos2 = [_spawnPos2 select 0, _spawnPos2 select 1, 50];
				    _transClass = _grp call fnc_pickAirTransport;
					_ret = [_spawnPos2, (floor (random 360)), _transClass, EAST] call EVO_fnc_spawnvehicle;
				    _heli = _ret select 0;
				    _heliGrp = _ret select 2;
					_heliGrp setVariable ["Vcm_Disable",true];
				    {
						if (HCconnected) then {
							handle = [_x] call EVO_fnc_sendToHC;
						};
					} forEach units _heliGrp;
				    {
				    	_x assignAsCargo _heli;
				    	_x moveInCargo _heli;
				    } forEach units _grp;
				    if ([true, false, false] call bis_fnc_selectRandom) then {
				    	//paradrop
						_goTo = [position currentTargetRT] call fnc_randomPosition; 
					    _heli doMove _goTo;
					    _heli flyInHeight 150;
					    waitUntil { sleep 1;(_heli distance2D _goTo < 200) || !alive _heli || isNull _heli};
					    handle = [_heli] spawn EVO_fnc_paradrop;
					    //doStop _heli;
					    _heli doMove getPos server;
					    handle = [_heli] spawn {
					    	_heli = _this select 0;
					    	waitUntil { sleep 1;(_heli distance2D server) < 1000 || !alive _heli || isNull _heli};
					    	{
					    		deleteVehicle _x;
					    	} forEach units group driver _heli;
					    	deleteVehicle _heli;
						};

			    		if ([true, true, true, false, false, false, false, false, false, false, false] call bis_fnc_selectRandom) then {
							[_grp, getPos currentTargetRT, 100] call CBA_fnc_taskDefend;
						} else {
							[_grp, getPos currentTargetRT, 100] call CBA_fnc_taskPatrol;
						};

					} else {
						//land
						_lz = current_landing_zones call bis_fnc_selectRandom;
						_goTo = position _lz;
						_heli flyInHeight 25;
						[group _heli, _goTo, _lz] spawn BIS_fnc_wpLand;
					    waitUntil { sleep 1;(_heli distance2D _goTo) < 100 || !alive _heli || isNull _heli};
					    {
					    	unassignVehicle  _x;
					    	doGetOut _x
					    } forEach units _grp;
					    _grp leaveVehicle _heli;
						_smoke = "SmokeShellWhite" createVehicle getpos _heli;
					    _heli doMove getPos server;
					    handle = [_heli] spawn {
					    	_heli = _this select 0;
					    	waitUntil { sleep 1;{_x distance2D _heli < 1500} count allPlayers < 1 || !alive _heli || isNull _heli};
					    	deleteVehicleCrew _heli;
					    	deleteVehicle _heli;
						};

			    		if ([true, true, true, false, false, false, false, false, false, false, false] call bis_fnc_selectRandom) then {
							[_grp, getPos currentTargetRT, 100] call CBA_fnc_taskDefend;
						} else {
							[_grp, getPos currentTargetRT, 100] call CBA_fnc_taskPatrol;
						};

					};
				};
			};
		};
    };
    case "armor": {
    		if (_init) then {
	    		_spawnPos = [position currentTarget, 10, 500, 10, 0, 2, 0, [], [getPos server, getPos server]] call BIS_fnc_findSafePos;
	    	} else {
				_roads = (position (targetLocations select (targetCounter + 1))) nearRoads 500;
				_nearestRoad = _roads call BIS_fnc_selectRandom;
				_spawnPos = getPos _nearestRoad;
	    	};
			_ret = [_spawnPos, (floor (random 360)), (EVO_opforVehicles call BIS_fnc_selectRandom), EAST] call EVO_fnc_spawnvehicle;
			_tank = _ret select 0;
			_grp = _ret select 2;
			{
				if (HCconnected) then {
					handle = [_x] call EVO_fnc_sendToHC;
				};
				currentAOunits pushBack _x;
				publicVariable "currentAOunits";
				_x AddMPEventHandler ["mpkilled", {
					currentAOunits = currentAOunits - [_this select 1];
					publicVariable "currentAOunits";
				}];
			} forEach units _grp;
			_heavylift = [false, true] call BIS_fnc_selectRandom;
			if (_heavylift && !_init) then {
				_spawnPos = [position (targetLocations select (targetCounter + 1))] call fnc_randomPosition; 
				_ret = [_spawnPos, (floor (random 360)), EVO_opforHeavyLift, EAST] call EVO_fnc_spawnvehicle;
				_heli = _ret select 0;
				_heliGrp = _ret select 2;
				_heliGrp setVariable ["Vcm_Disable",true];
				[_heli, _tank] spawn {
					_heli = _this select 0;
					_tank = _this select 1;
					_heli setSlingLoad _tank;
					driver _heli disableAI "FSM";
					driver _heli disableAI "TARGET";
					driver _heli disableAI "AUTOTARGET";
					group driver _heli setBehaviour "CARELESS";
					group driver _heli setCombatMode "BLUE";
					group driver _heli setSpeedMode "FULL";
					_heli setSpeedMode "LIMITED";
					_lz = [position currentTarget, 150, 500, 10, 0, 2, 0, [], [getPos server, getPos server]] call BIS_fnc_findSafePos;
					driver _heli doMove _lz;
					_heli flyInHeight 55;
					_heli lock 3;
					waitUntil { sleep 1;(_heli distance2D _lz < 100)};
					_heli flyInHeight 0;
					waitUntil {isTouchingGround _tank || !alive _tank || !alive _heli || isNull _heli || isNull _tank};
					{
						ropeCut [ _x, 5];
					} forEach ropes _heli;
			    	[group driver _tank, getmarkerpos currentTargetMarkerName, 300] call CBA_fnc_taskPatrol;
					_heli setSpeedMode "FULL";
					_heli land "NONE";
					driver _heli doMove getPos server;
					_heli flyInHeight 25;
					[_heli] spawn {
						_heli = _this select 0;
					    waitUntil { sleep 1;{_x distance2D _heli < 1500} count allPlayers < 1 || !alive _heli || isNull _heli };
						{
							deleteVehicle _x;
						} forEach crew _heli;
						deleteVehicle _heli;
					};
				};
			} else {

			    [_grp, getmarkerpos currentTargetMarkerName, 300] call CBA_fnc_taskPatrol;
			};

    };
    default {
     	["EVO_fnc_sendToAO threw DEFAULT switch."] call BIS_fnc_error;
    };
};

_grp;

