//////////////////////////////////////
//Init Global EVO Variables
//////////////////////////////////////


_locs = nearestLocations [spawnBuilding, ["NameLocal","NameCity", "NameCityCapital", "NameVillage"], [] call BIS_fnc_mapSize];
sideLocations = _locs;
publicVariable "sideLocations";
//LocationBase_F
militaryLocations = nearestObjects [spawnBuilding, ["LocationBase_F"], [] call BIS_fnc_mapSize];
targetLocations = [];
targetObjects = [obj, obj_1, obj_2, obj_3, obj_4, obj_5, obj_6, obj_7, obj_8, obj_9, obj_10];
{
	_closesttown = (nearestLocations [(getPos _x),["NameCityCapital","NameCity","NameVillage"],10000]) select 0;
	targetLocations = targetLocations + [_closesttown];
} forEach targetObjects;
totalTargets = count targetLocations;
if (isNil "targetCounter") then {
	targetCounter = 0;
} else {
	for "_i" from 3 to targetCounter step 1 do {
		_marker = format ["%1", _i];
		_currentTarget = targetLocations select _i;
		_mrkr = createMarker [_marker, position _currentTarget];
		_marker setMarkerPos (position _currentTarget);
		_marker setMarkerSize [(((size _currentTarget) select 0) + 200), (((size _currentTarget) select 1) + 200)];
		_marker setMarkerDir direction _currentTarget;
		_marker setMarkerShape "ELLIPSE";
	  	_marker setMarkerBrush "SOLID";
		_marker setMarkerColor "ColorWEST";
	};
};
currentTarget = targetLocations select targetCounter;
currentTargetName = text currentTarget;
currentTargetRT = nil;
currentTargetOF = nil;
RTonline = true;
officerAlive = true;
markerCounter = 0;
"opforair" setMarkerAlpha 0;
"counter" setMarkerAlpha 0;
"counter_1" setMarkerAlpha 0;
currentSideMission = "none";
currentSideMissionMarker = "nil";
nextTargetMarkerName = "nil";
availableSideMissions = [];
currentSideMissionStatus = "ip";
EVO_supportUnits = [arty_west, mortar_west, rocket_west, uav_west];
currentAOunits = [];
publicVariable "currentAOunits";

//////////////////////////////////////
//Check All Vehicles on Map
//////////////////////////////////////
{
	_vehicle = _x;
	//////////////////////////////////////
	//Setup BLUFOR Vehicle Respawn/Repair Systems
	//////////////////////////////////////
	if (faction _vehicle == "BLU_F" || faction _vehicle == "BLU_GEN_F") then {
		if (toUpper(typeOf _vehicle) == "B_MRAP_01_F" || faction _vehicle == "BLU_GEN_F")	then {
			_null = [_vehicle] spawn EVO_fnc_basicRespawn;
		} else {
			if (!(_vehicle isKindOf "Plane") && !(_vehicle isKindOf "Man")) then {
				_null = [_vehicle] spawn EVO_fnc_respawnRepair;
			} else {
				if (_vehicle isKindOf "Plane") then {
					_null = [_vehicle] spawn EVO_fnc_basicRespawn;
				};
			};
		};
	};
	//////////////////////////////////////
	//Setup OPFOR AAA
	//////////////////////////////////////
	if (typeOf _vehicle == EVO_opforAAA) then {
		_ret = [_vehicle] spawn {
			_vehicle = _this select 0;
			_pos = position _vehicle;
			deleteVehicle _vehicle;
			if (isServer) then {
				_nearObjs = nearestTerrainObjects [_pos, [], 25];
				{ _x hideObjectGlobal true } forEach _nearObjs;
			};
			_compReference  = ["evo_aa", _pos, [0,0,0], (random 360)] call LARs_fnc_spawnComp;
			_aaComp = [_compReference] call LARs_fnc_getCompObjects;
			_missles1 = objNull;
			_missles2 = objNull;
			_radar = objNull;
			{
				if (typeName _x == "OBJECT") then {
					if (side _x == EAST) then {
						if (toLower(typeOf _x) == toLower("O_Radar_System_02_F")) then {
							_radar = _x;
						};
						if (toLower(typeOf _x) == toLower("O_SAM_System_04_F")) then {
							if (_missles1 == objNull) then {
								_missles1 = _x;
								_missles1 addEventHandler ["Fired",{ 
									_ret = [_this select 0] spawn {
										sleep 120;
										if (alive _this select 0) then {_this select 0 setVehicleAmmo 1};
									};
								}];
							} else {
								_missles2 = _x;
								_missles2 addEventHandler ["Fired",{ 
									_ret = [_this select 0] spawn {
										sleep 120;
										if (alive _this select 0) then {_this select 0 setVehicleAmmo 1};
									};
								}];
							};
						};
					};
				};
			} forEach _aaComp;
			_markerName = format ["aa_%1", markerCounter];
			_aaMarker = createMarker [_markerName, position _radar];
			_markerName setMarkerShape "ELLIPSE";
			_markerName setMarkerBrush "Cross";
			_markerName setMarkerSize [1200, 1200];
			_markerName setMarkerColor "ColorEAST";
			_markerName setMarkerPos (GetPos _radar);
			markerCounter = markerCounter + 1;
			_radar setVariable ["EVO_markerName", _markerName, true];
			_radar AddEventHandler ["Killed", {
				deleteMarker ((_this select 0) getVariable "EVO_markerName");
				_missles1 disableAI "ALL";
				_missles1 setDamage 1;
				_missles2 disableAI "ALL";
				_missles2 setDamage 1;
				_ret = [_radar, _aaComp] spawn {
					_radar = _this select 0;
					_aaComp = _this select 1;
					waitUntil { sleep 10;  {_x distance2D _radar < 1500} count allPlayers < 1 };
					{
						if (typeName _x == "OBJECT") then {
							deleteVehicle _x;
						};
					} forEach _aaComp;
				};
			}];
		};
	};
} forEach vehicles;

//////////////////////////////////////
//Init First Target
//////////////////////////////////////
evoInit = true;
publicVariable "evoInit";
handle = [] spawn EVO_fnc_initTarget;




