params ["_player", "_didJIP"];

// Only initialize if player is alive
if (alive _player) then {
    // Initialize variables for this player
    _player setVariable ["vecupdate", [0,0,0], true];
    _player setVariable ["movez", 0, true];

    // Start jetpack script for this player
    [_player] execVM "scripts\zerograv\zg_new.sqf";
};

// Add event handler to check backpack changes
_player addEventHandler ["Take", {
    params ["_unit", "_container", "_item"];
    if (_item == "B_CombinationUnitRespirator_01_F") then {
        _unit setVariable ["zerog", true, true];
        [_unit] execVM "scripts\zerograv\zg_new.sqf";
    };
}];

_player addEventHandler ["Put", {
    params ["_unit", "_container", "_item"];
    if (_item == "B_CombinationUnitRespirator_01_F") then {
        _unit setVariable ["zerog", false, true];
        _unit enableAI "ANIM"; // Re-enable voluntary stance changes
        _unit playMove "AmovPercMstpSnonWrflDnon"; // Reset animation when removing jetpack
    };
}];

// Handle AI units with jetpack
addMissionEventHandler ["EachFrame",{
    private _zgai = (allUnits + vehicles) select {_x getVariable ["zgai",false]};
    {_x setVelocity [0,0,0];} forEach _zgai;
}];

_player addEventHandler ["respawn", {
    params ["_unit"];
    if (backpack _unit == "B_CombinationUnitRespirator_01_F") then {
        _unit setVariable ["zerog", true, true];
    };
}];

_player addEventHandler ["GetIn", {
    params ["_vehicle", "_role", "_unit", "_turret"];
    if (backpack _unit == "B_CombinationUnitRespirator_01_F") then {
        _unit setVariable ["zerog", false, true];
        _unit enableAI "ANIM"; // Re-enable voluntary stance changes
        _unit playMove "AmovPercMstpSnonWrflDnon"; // Reset animation when entering vehicle
    };
}];

_player addEventHandler ["GetOut", {
    params ["_vehicle", "_role", "_unit", "_turret"];
    if (backpack _unit == "B_CombinationUnitRespirator_01_F") then {
        _unit setVariable ["zerog", true, true];
    };
}]; 