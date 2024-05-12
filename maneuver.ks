//maneuver
// this script executes the next maneuver node

// clear screen to display only important information
print "RUNNING maneuver".

set nd to nextNode.

// calculate crude estimate of burn duration, assuming constant mass (bad assumption)
lock availableAcceleration to availableThrust/mass.
set burnDuration to nd:deltav:mag/availableAcceleration.
print("Estimated burn duration of " + round(burnDuration) + " seconds").

// add a Kerbal Alarm Clock alarm to kick simulation out of warp a minute before the burn should start.
local burnStart is burnDuration/2.
addAlarm("Maneuver", time:seconds + nd:eta - (burnStart + 60), "Maneuver Node", "Auto-Generated by kOS script").
wait until nd:eta <= burnStart + 60.

// turn to face the direction the rocket's velocity is changing in
set dv0 to nd:deltaV.
lock steering to dv0.

// wait until rocket is facing the right direction
wait until vang(dv0, ship:facing:vector) < 0.25.

// wait until burn start
wait until nd:eta <= burnStart + 1.
kuniverse:timewarp:cancelwarp().
wait until kuniverse:timewarp:isSettled().
wait until nd:eta <= burnStart.

// create a setpoint we can manipulate
set throttleSetpoint to 0.
lock throttle to throttleSetpoint.

// execute maneuver node
until vDot(dv0, nd:deltav) < 0 {
    set throttleSetpoint to min(nd:deltav:mag/availableAcceleration, 1).

    if nd:deltaV:mag < 0.1 {
        wait until vDot(dv0, nd:deltav) < 0.5.
        break.
    }
}

// print stats
print "End burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).

// unlock controls
unlock steering.
unlock throttle.

// sets user's throttle setting to zero to prevent throttle from
// returning to the throttle value it was before it was run
set ship:control:pilotMainThrottle to 0.

// unlock steering and turn on stability assist
unlock steering.
sas on.