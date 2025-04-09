// Initialize local variables for this unit
private _movez = 0;
private _vectrue = [0,0,0];
private _unit = _this select 0;
private _zerog = true;  // Start with zero gravity enabled
private _isFlying = false;  // New variable to track if player is actually flying
private _refuelStatus = "";  // New variable to track refuel status
private _strafeBoostLeftEndTime = _unit getVariable ["strafeBoostLeftEndTime", 0]; // Add boost timers
private _strafeBoostRightEndTime = _unit getVariable ["strafeBoostRightEndTime", 0]; // Add boost timers
private _strafeBoostLeftCooldownEndTime = _unit getVariable ["strafeBoostLeftCooldownEndTime", 0]; // Add cooldown timers
private _strafeBoostRightCooldownEndTime = _unit getVariable ["strafeBoostRightCooldownEndTime", 0]; // Add cooldown timers

_unit setUnitFreefallHeight 9999;

// Add fuel system (in liters)
if (isNil "jetpackFuel") then {
    jetpackFuel = 100; // 100 liters of fuel
};

// Add acceleration variables
if (isNil "currentSpeed") then {
    currentSpeed = 0;
};

// Function to get key names
fnc_getKeyName = {
    params ["_action"];
    private _keyName = "Not Set";
    private _keys = actionKeys _action;
    if (count _keys > 0) then {
        private _keyCode = _keys select 0;
        _keyName = switch (_keyCode) do {
            case 16: "Q";
            case 17: "W";
            case 18: "E";
            case 19: "R";
            case 20: "T";
            case 21: "Y";
            case 22: "U";
            case 23: "I";
            case 24: "O";
            case 25: "P";
            case 30: "A";
            case 31: "S";
            case 32: "D";
            case 33: "F";
            case 34: "G";
            case 35: "H";
            case 36: "J";
            case 37: "K";
            case 38: "L";
            case 44: "Z";
            case 45: "X";
            case 46: "C";
            case 47: "V";
            case 48: "B";
            case 49: "N";
            case 50: "M";
            case 42, 298: "Left Shift";
            case 29: "Left Ctrl";
            case 56: "Left Alt";
            case 57: "Space";
            case 28: "Enter";
            case 1: "Esc";
            case 14: "Backspace";
            case 15: "Tab";
            case 59: "F1";
            case 60: "F2";
            case 61: "F3";
            case 62: "F4";
            case 63: "F5";
            case 64: "F6";
            case 65: "F7";
            case 66: "F8";
            case 67: "F9";
            case 68: "F10";
            case 87: "F11";
            case 88: "F12";
            default { format ["Key %1", _keyCode]; };
        };
        if (count _keys > 1) then { _keyName = format ["2 x %1", _keyName]; };
    };
    _keyName
};

// Store unit's jetpack state
_unit setVariable ["zerog", _zerog, true];
_unit setVariable ["isFlying", _isFlying, true];

// Define the jetpack update function
private _fnc_jetpackUpdate = {
    private _unit = player;
    private _zerog = _unit getVariable ["zerog", false];
    private _isFlying = _unit getVariable ["isFlying", false];
    private _movez = _unit getVariable ["movez", 0];
    private _vectrue = _unit getVariable ["vectrue", [0,0,0]];
    private _strafeBoostLeftEndTime = _unit getVariable ["strafeBoostLeftEndTime", 0];
    private _strafeBoostRightEndTime = _unit getVariable ["strafeBoostRightEndTime", 0];
    private _strafeBoostLeftCooldownEndTime = _unit getVariable ["strafeBoostLeftCooldownEndTime", 0];
    private _strafeBoostRightCooldownEndTime = _unit getVariable ["strafeBoostRightCooldownEndTime", 0];
    
    if (backpack _unit == "B_CombinationUnitRespirator_01_F") then {
        private _alt = (getPosASL _unit) select 2;
        private _isOnGround = (getPos _unit select 2) < 0.5;
        
        // Only allow jetpack operation with fuel and if unit is alive
        if (jetpackFuel > 0 && alive _unit) then {
            // Handle takeoff boost
            if (inputAction "User3" > 0 && !_isFlying && _isOnGround) then {
                private _boostForce = 5.0 * 3.0;  // Base acceleration * multiplier
                _movez = 15.0; // Initial vertical boost
                _isFlying = true;
                _unit setVariable ["isFlying", true, true];
                
                // Force the jetpack animation
                _unit switchMove "AmovPercMstpSrasWrflDnon";  // Changed to a more neutral stance
                _unit disableAI "ANIM"; // Disable voluntary stance changes
                
                // Disable stance change keys while flying
                disableUserInput true;
                disableUserInput false;
                disableUserInput ["Prone", "Crouch", "Stand"];
                
                // Get unit's direction for takeoff
                private _unitDir = getDir _unit;
                private _unitDirRad = _unitDir * (pi / 180);
                private _forwardVector = [sin _unitDirRad, cos _unitDirRad, 0];
                
                // Add forward momentum for better takeoff
                private _forwardBoost = _forwardVector vectorMultiply (_boostForce * 4.0);
                _vectrue = [
                    _forwardBoost select 0,
                    _forwardBoost select 1,
                    _movez
                ];
                
                // Apply immediate velocity for responsive takeoff
                _unit setVelocity _vectrue;
                
                // Prevent sprint animation and ensure jetpack state
                private _unitRef = _unit;
                _unit allowDamage false;
                
                [_unitRef] spawn {
                    params ["_unitRef"];
                    sleep 0.1;
                    _unitRef allowDamage true;
                };
            };
            
            // Only apply jetpack physics if actually flying
            if (_isFlying) then {
                // Reduce fuel when thrusting or boosting
                private _fuelConsumed = 0.0;
                if (inputAction "MoveForward" > 0 || inputAction "TurnLeft" > 0 ||
                    inputAction "TurnRight" > 0 || inputAction "MoveBack" > 0 ||
                    inputAction "User1" > 0 || inputAction "User2" > 0 || // Include vertical thrust
                    inputAction "User3" > 0 || // Include takeoff/forward boost
                    serverTime < _strafeBoostLeftEndTime || serverTime < _strafeBoostRightEndTime) // Include active strafe boosts
                then {
                    _fuelConsumed = _fuelConsumed + 0.01; // Base fuel cost
                };

                // Add extra fuel cost for active strafe boosts
                if (serverTime < _strafeBoostLeftEndTime || serverTime < _strafeBoostRightEndTime) then {
                     _fuelConsumed = _fuelConsumed + 0.05; // Additional boost fuel cost
                };
                jetpackFuel = jetpackFuel - _fuelConsumed;
                
                // Apply physics with acceleration
                private _veccurent = velocity _unit;
                
                // Get player's direction vector (normalized)
                private _playerDir = vectorDir _unit;
                private _playerUp = [0, 0, 1];
                private _playerRight = [
                    (_playerDir select 1) * (_playerUp select 2) - (_playerDir select 2) * (_playerUp select 1),
                    (_playerDir select 2) * (_playerUp select 0) - (_playerDir select 0) * (_playerUp select 2),
                    (_playerDir select 0) * (_playerUp select 1) - (_playerDir select 1) * (_playerUp select 0)
                ];
                
                // Calculate horizontal movement based on WASD input
                private _horizontalAccel = [0, 0, 0];
                private _accelMultiplier = 90.0;  // Halved from 180.0 to 90.0 for slower base movement
                
                // Forward movement (W)
                if (inputAction "MoveForward" > 0) then {
                    _horizontalAccel = _horizontalAccel vectorAdd (_playerDir vectorMultiply _accelMultiplier);
                };
                
                // Backward movement (S)
                if (inputAction "MoveBack" > 0) then {
                    _horizontalAccel = _horizontalAccel vectorAdd (_playerDir vectorMultiply -_accelMultiplier);
                };
                
                // Left movement (A)
                if (inputAction "TurnLeft" > 0) then {
                    _horizontalAccel = _horizontalAccel vectorAdd (_playerRight vectorMultiply -_accelMultiplier);
                };
                
                // Right movement (D)
                if (inputAction "TurnRight" > 0) then {
                    _horizontalAccel = _horizontalAccel vectorAdd (_playerRight vectorMultiply _accelMultiplier);
                };
                
                // Handle in-flight boost (User3 - Forward)
                if (inputAction "User3" > 0) then {
                    private _boostForce = _accelMultiplier * 2.0; // Keep forward boost relative to base accel
                    _horizontalAccel = _horizontalAccel vectorAdd (_playerDir vectorMultiply _boostForce);
                };

                // Handle rapid strafing trigger (User4/User5)
                private _strafeBoostForce = _accelMultiplier * 2.0; // 2x the (halved) WASD speed = 180.0
                private _cooldownDuration = 15.0; // Increased cooldown to 15 seconds

                // Trigger Left Strafe Boost (User4)
                if (inputAction "User4" > 0 && _strafeBoostLeftEndTime <= serverTime && _strafeBoostLeftCooldownEndTime <= serverTime) then {
                    _strafeBoostLeftEndTime = serverTime + 2.0; // Start 2 second boost timer
                    _strafeBoostLeftCooldownEndTime = _strafeBoostLeftEndTime + _cooldownDuration; // Start cooldown timer after boost ends
                };
                // Trigger Right Strafe Boost (User5)
                if (inputAction "User5" > 0 && _strafeBoostRightEndTime <= serverTime && _strafeBoostRightCooldownEndTime <= serverTime) then {
                    _strafeBoostRightEndTime = serverTime + 2.0; // Start 2 second boost timer
                    _strafeBoostRightCooldownEndTime = _strafeBoostRightEndTime + _cooldownDuration; // Start cooldown timer after boost ends
                };

                // Apply active strafe boosts
                if (serverTime < _strafeBoostLeftEndTime) then {
                    _horizontalAccel = _horizontalAccel vectorAdd (_playerRight vectorMultiply -_strafeBoostForce);
                };
                if (serverTime < _strafeBoostRightEndTime) then {
                    _horizontalAccel = _horizontalAccel vectorAdd (_playerRight vectorMultiply _strafeBoostForce);
                };
                
                // Handle vertical movement
                private _verticalSpeed = 25.0;  // Increased by 25% from 20.0 to 25.0
                if (inputAction "User1" > 0) then {
                    _movez = _verticalSpeed;  // Set constant upward speed
                } else {
                    if (inputAction "User2" > 0) then {
                        _movez = -_verticalSpeed;  // Set constant downward speed
                    } else {
                        // If neither key is pressed, maintain current vertical speed
                        // but apply slight drag
                        _movez = _movez * 0.99;
                    };
                };
                
                // Apply acceleration directly
                _vectrue = _horizontalAccel;
                
                // Reduced gravity effect for better control
                if ((_horizontalAccel select 0 == 0) && (_horizontalAccel select 1 == 0) && (_horizontalAccel select 2 == 0) && !(inputAction "User1" > 0)) then {
                    _movez = _movez - 0.005;
                };
                
                // Apply velocity with minimal drag
                private _dragFactor = 0.99;  // Increased drag for better control
                private _newVelocity = [
                    (_vectrue select 0) * _dragFactor,
                    (_vectrue select 1) * _dragFactor,
                    _movez
                ];
                
                // Apply the final velocity
                _unit setVelocity _newVelocity;
                
                // Handle landing and protection
                if (_isOnGround && _movez < 0 && abs _movez > 0.1) then {
                    // Reset flight state and animation
                    _isFlying = false;
                    _unit setVariable ["isFlying", false, true];
                    _movez = _movez * 0.5;
                    _vectrue = _vectrue vectorMultiply 0.5;
                    _unit enableAI "ANIM";
                    _unit switchMove "AmovPknlMstpSrasWrflDnon";
                    
                    // Simple velocity application
                    _unit setVelocity [(_vectrue select 0) * 0.5, (_vectrue select 1) * 0.5, 0];
                    
                    // Reset variables and enable protection
                    _unit setVariable ["movez", 0, true];
                    _unit setVariable ["vectrue", [0,0,0], true];
                    _unit setVariable ["landingProtection", true, true];
                    _unit setVariable ["landingProtectionTime", serverTime, true];
                    enableUserInput true;
                    _unit allowDamage false;
                };
                
                // Check and remove protection if needed
                if (_unit getVariable ["landingProtection", false]) then {
                    if ((serverTime - (_unit getVariable ["landingProtectionTime", 0])) > 2.0) then {
                        _unit allowDamage true;
                        _unit setVariable ["landingProtection", false, true];
                    };
                };
                
                // Update unit's variables
                _unit setVariable ["movez", _movez, true];
                _unit setVariable ["vectrue", _vectrue, true];
                _unit setVariable ["strafeBoostLeftEndTime", _strafeBoostLeftEndTime, true];
                _unit setVariable ["strafeBoostRightEndTime", _strafeBoostRightEndTime, true];
                _unit setVariable ["strafeBoostLeftCooldownEndTime", _strafeBoostLeftCooldownEndTime, true];
                _unit setVariable ["strafeBoostRightCooldownEndTime", _strafeBoostRightCooldownEndTime, true];
            } else {
                // No fuel behavior
                _zerog = false;
                _isFlying = false;
                _unit setVariable ["zerog", false, true];
                _unit setVariable ["isFlying", false, true];
                hint "Jetpack fuel depleted!";
            };
        };
    };
};

// Add the event handler
addMissionEventHandler ["EachFrame", _fnc_jetpackUpdate];

// Add fuel regeneration when near refuel points
0 spawn {
    while {true} do {
        private _unit = player;
        private _isFlying = _unit getVariable ["isFlying", false];
        
        if (!_isFlying && backpack _unit == "B_CombinationUnitRespirator_01_F") then {
            private _unitPos = getPos _unit;
            private _nearbyRefuelPoints = [];
            
            // Check for all possible refuel station types
            {
                _nearbyRefuelPoints = _nearbyRefuelPoints + (_unitPos nearObjects [_x, 5]);  // Reduced range and using nearObjects
            } forEach [
                "Land_fs_feed_F",
                "Land_FuelStation_Feed_F",
                "Land_FuelStation_01_F",
                "Land_FuelStation_02_F",
                "Land_FuelStation_03_F",
                "Land_FuelStation_01_pump_F",
                "Land_FuelStation_02_pump_F",
                "Land_FuelStation_03_pump_F",
                "B_Truck_01_fuel_F",
                "O_Truck_03_fuel_F",
                "I_Truck_02_fuel_F",
                "Land_Ind_FuelStation_Feed_F",
                "Land_Ind_FuelStation_01_F",
                "Land_Ind_FuelStation_02_F"
            ];
            
            if (count _nearbyRefuelPoints > 0) then {
                if (jetpackFuel < 100) then {
                    jetpackFuel = (jetpackFuel + 1.0) min 100; // Increased refuel rate from 0.5 to 1.0
                    _unit setVariable ["refuelStatus", "REFUELING", true];
                } else {
                    _unit setVariable ["refuelStatus", "FULL", true];
                };
            } else {
                _unit setVariable ["refuelStatus", "", true];
            };
        };
        sleep 0.5;
    };
}; 