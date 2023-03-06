spendable = [player] call EVO_fnc_supportPoints;
    if (spendable >= 4 && !hasUAV) then {
      uavComm = [player, "uavRequest"] call BIS_fnc_addCommMenuItem;
      hasUAV = true;
    };
    if (spendable >= 5 && !hasMortar) then {
      mortarStrikeComm = [player, "mortarStrike"] call BIS_fnc_addCommMenuItem;
      hasMortar = true;
    };

    if (spendable >= 6 && !hasArty) then {
      artyStrikeComm = [player, "artyStrike"] call BIS_fnc_addCommMenuItem;
      hasArty = true;
    };

    if (spendable >= 7 && !hasCas) then {
      casStrikeComm = [player, "fixedCasStrike"] call BIS_fnc_addCommMenuItem;
      hasCas = true;
    };

    if (spendable >= 8 && !hasRocket) then {
      rocketStrikeComm = [player, "rocketStrike"] call BIS_fnc_addCommMenuItem;
      hasRocket = true;
    };
    if (spendable >= 9) then {
      //arty?
    };

    if (spendable >= 10) then {
      //icbm?
    };

    //
    //
    //
    if (spendable < 4 && hasUAV) then {
      [player, "uavRequest"] call BIS_fnc_removeCommMenuItem;
      hasMortar = false;
    };
    if (spendable < 5 && hasMortar) then {
      [player, "mortarStrike"] call BIS_fnc_removeCommMenuItem;
      hasMortar = false;
    };

    if (spendable < 6 && hasArty) then {
      [player, "artyStrike"] call BIS_fnc_removeCommMenuItem;
      hasArty = false;
    };

    if (spendable < 7 && hasCas) then {
      [player, "fixedCasStrike"] call BIS_fnc_removeCommMenuItem;
      hasCas = false;
    };

    if (spendable < 8 && hasRocket) then {
      [player, "rocketStrike"] call BIS_fnc_removeCommMenuItem;
      hasRocket = false;
    };

    if (spendable < 9) then {

    };

    if (spendable < 10) then {

    };
