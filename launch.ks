//launch

// these defaults seem to work well when launching from KSC
declare parameter finalAltitude is 80000.
declare parameter compassHeading is 90.
declare parameter turnRate is 12.

// clear screen to display only important information
clearScreen.
print "RUNNING launch".

// define utility functions
runoncepath("utils/miscUtils.ks").
runoncepath("utils/engineUtils.ks").

// countdown to launch
print "Count down:".
from {local countdown is 3.} until countdown = 0 step {set countdown to countdown - 1.} do {
    print "..." + countdown.
    wait 1.
}

// setup trigger to stage whenever thrust is zero or static engines flameout
when maxThrust = 0 or staticFlameout() then {
    print "Staging.".
    stage.
    wait until stage:ready.
    preserve.
}

// setup trigger to deploy action group 1 (solar panels, antennas, etc.) at less than 0.01 dynamic pressure
when ship:velocity:surface:mag > 1000 and ship:dynamicpressure < 0.01 then {
    ag1 on.
}

// setup constants and variables for launch
set targetTWR to 2.0.
lock gravAcc to body:mu/((body:radius + altitude)*(body:radius + altitude)).
lock weight to gravAcc * mass.
lock throttle to throttleForThrust(targetTWR * weight).
set initialSpeed to 100.

sas on.
set sasMode to "stability".
set yaw to compassHeading.
set pitch to 90.

when ship:velocity:surface:mag > initialSpeed then {
    sas off.
    lock steering to heading(yaw, pitch).
}

// execute launch up until ship's apoapsis is at target
until ship:apoapsis > finalAltitude {
    // launch straight up with no turning
    if ship:velocity:surface:mag < initialSpeed {
        print "Accelerating to " + initialSpeed + " m/s" at(0,15).
    
    // pitch down in accordance to turn rate
    } else if ship:velocity:surface:mag >= initialSpeed and ship:velocity:surface:mag < 80*turnRate+initialSpeed {
        set pitch to 90 - (ship:velocity:surface:mag-initialSpeed)/turnRate.
        set yaw to compassHeading.
        print "Pitching to " + round(pitch) + " degrees           " at (0,15).
    } else if ship:velocity:surface:mag >= 80*turnRate+initialSpeed {
        set pitch to 10.
        set yaw to compassHeading.
        print "Pitching to 10 degrees" at (0,15).
    }
}

// Cut throttle and coast until ship exits atmosphere
clearline(15).
print "Reached apoapsis of " + round(apoapsis) + " meters, cutting throttle" at (0,15).
print "Cruising to " + round(ship:body:atm:height) + " meters" at (0,16).
lock throttle to 0.
wait until ship:altitude > ship:body:atm:height.

// burn again to account for air friction losses
if ship:apoapsis < finalAltitude {
    kuniverse:timewarp:cancelwarp().
    wait until kuniverse:timewarp:isSettled().
    lock throttle to throttleForThrust(targetTWR * weight).
    wait until ship:apoapsis > finalAltitude.
    lock throttle to 0.
}

// sets user's throttle setting to zero to prevent throttle from
// returning to the throttle value it was before it was run
set ship:control:pilotMainThrottle to 0.

// unlock steering and turn on stability assist
unlock steering.
sas on.

// if it's possible to make nodes, create and execute a circularization node
if career():canMakeNodes {
    runoncepath("utils/nodeUtils.ks").

    // create circularization maneuver node
    local circNode is nodeChangePeriapsis(apoapsis).
    if circNode:isType("Node") {
        add circNode.

        clearScreen.
        print "Reached apoapsis of " + round(apoapsis) + " meters, cutting throttle" at (0,15).
        print "Executing circularization node in " + round(circNode:eta) + " seconds" at (0,16).

        // run execute next node script
        run maneuver.
    }
// else just point sas at prograde
} else {
    set sasMode to "prograde".
}