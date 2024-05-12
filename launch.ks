//launch

declare parameter finalAltitude, compassHeading, turnRate.

// clear screen to display only important information
clearScreen.
print "RUNNING launch".

// define utility functions
runoncepath("utils/miscUtils.ks").
runoncepath("utils/nodeUtils.ks").

// countdown to launch
print "Count down:".
from {local countdown is 3.} until countdown = 0 step {set countdown to countdown - 1.} do {
    print "..." + countdown.
    wait 1.
}

// setup trigger to stage whenever thrust is zero
when maxThrust = 0 then {
    print "Staging.".
    stage.
    preserve.
}

// setup trigger to deploy action group 1 (solar panels, antennas, etc.) at less than 0.01 dynamic pressure
when ship:velocity:surface:mag > 1000 and ship:dynamicpressure < 0.01 then {
    ag1 on.
}

// setup constants and variables for launch
set targetTWR to 2.0.
lock weight to ship:sensors:grav:mag * mass.
lock throttle to choose targetTWR*weight/availableThrust if availableThrust > 0 else 0.
set initialSpeed to 100.
set yaw to 0.
set pitch to 90.
lock steering to heading(yaw, pitch).

// execute launch up until ship's apoapsis is at target
until ship:apoapsis > finalAltitude {
    // launch straight up with no turning
    if ship:velocity:surface:mag < initialSpeed {
        print "Accelerating to " + initialSpeed + " m/s" at(0,15).
    
    // pitch down in accordance to turn rate
    } else if ship:velocity:surface:mag >= initialSpeed and ship:velocity:surface:mag < 80*turnRate+initialSpeed {
        set pitch to 90 - (ship:velocity:surface:mag-initialSpeed)/turnRate.
        set yaw to compassHeading.
        print "Pitching to " + round(pitch,0) + " degrees           " at (0,15).
    } else if ship:velocity:surface:mag >= 80*turnRate+initialSpeed {
        set pitch to 10.
        set yaw to compassHeading.
        print "Pitching to 10 degrees" at (0,15).
    }
}

// Cut throttle and coast until ship exits atmosphere
clearline(15).
print "Reached apoapsis of " + round(apoapsis,0) + " meters, cutting throttle" at (0,15).
print "Cruising to " + round(ship:body:atm:height,0) + " meters" at (0,16).
lock throttle to 0.
wait until ship:altitude > ship:body:atm:height.

// burn again to account for air friction losses
if ship:apoapsis < finalAltitude {
    kuniverse:timewarp:cancelwarp().
    wait until kuniverse:timewarp:isSettled().
    lock throttle to choose targetTWR*weight/availableThrust if availableThrust > 0 else 0.
    wait until ship:apoapsis > finalAltitude.
    lock throttle to 0.
}

// create circularization maneuver node
local circNode is nodeChangePeriapsis(apoapsis).
add circNode.

clearScreen.
print "Reached apoapsis of " + round(apoapsis,0) + " meters, cutting throttle" at (0,15).
print "Executing circularization node in " + round(circNode:eta) + " seconds" at (0,16).

// run execute next node script
run maneuver.