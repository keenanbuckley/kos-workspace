//launch

parameter final_alt, compass_heading, turn_rate.

// clear screen to display only important information
clearScreen.
print "RUNNING launch".

// define utility functions
runoncepath("utils/misc_utils.ks").
runoncepath("utils/node_utils.ks").

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
set target_twr to 2.0.
lock weight to ship:sensors:grav:mag * mass.
lock throttle to choose target_twr*weight/availableThrust if availableThrust > 0 else 0.
set initial_speed to 100.
set yaw to 0.
set pitch to 90.
lock steering to heading(yaw, pitch).

// execute launch up until ship's apoapsis is at target
until ship:apoapsis > final_alt {
    // launch straight up with no turning
    if ship:velocity:surface:mag < initial_speed {
        print "Accelerating to " + initial_speed + " m/s" at(0,15).
    
    // pitch down in accordance to turn rate
    } else if ship:velocity:surface:mag >= initial_speed and ship:velocity:surface:mag < 80*turn_rate+initial_speed {
        set pitch to 90 - (ship:velocity:surface:mag-initial_speed)/turn_rate.
        set yaw to compass_heading.
        print "Pitching to " + round(pitch,0) + " degrees           " at (0,15).
    } else if ship:velocity:surface:mag >= 80*turn_rate+initial_speed {
        set pitch to 10.
        set yaw to compass_heading.
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
if ship:apoapsis < final_alt {
    kuniverse:timewarp:cancelwarp().
    wait 1.
    lock throttle to choose target_twr*weight/availableThrust if availableThrust > 0 else 0.
    wait until ship:apoapsis > final_alt.
    lock throttle to 0.
}

// create circularization maneuver node
local circNode is nodeChangePeriapsis(apoapsis).
add circNode.
clearline(15).
print "Reached apoapsis of " + round(apoapsis,0) + " meters, cutting throttle" at (0,15).
clearline(16).
print "Executing circularization node in " + circNode:eta + " seconds" at (0,16).

// run execute next node script
run maneuver.

// sets user's throttle setting to zero to prevent throttle from
// returning to the throttle value it was before it was run
set ship:control:pilotmainthrottle to 0.

// unlock steering and turn on stability assist
unlock steering.
sas on.