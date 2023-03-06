[[[_this select 0, _this select 1], {
	(_this select 0) sideChat (_this select 1);
	if (isPlayer (_this select 0)) then {(_this select 0) playAction "handSignalRadio"};
	(_this select 0) sideRadio "squelch";
}], "BIS_fnc_spawn", true] call BIS_fnc_MP;