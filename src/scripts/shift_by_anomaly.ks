// shift_by_anomaly.ks creates the maneuver nodes to execute a Bi-elliptic transfer to shift by an anomaly in degrees
@lazyGlobal off.

parameter deltaAnomaly is 0.   // Mean Anomaly to shift by in degrees
parameter apo is -1.            // final apoapsis (defaults to apoapsis of target patch)
parameter peri is -1.           // final periapsis (defaults to target apoapsis)

runOncePath("0:/src/core/orbit").

if orbit:eccentricity >= 1 {
    print "shift_by_anomaly requires an elliptical orbit.".
} else {
    if apo = -1 { set apo to apoapsis. }

    if peri = -1 { set peri to periapsis. }

    local targetOrbit is apoPeriToOrbit(apo, peri, body).

    print "Error in Mean Anomaly at Ownship Periapsis: " + deltaAnomaly.
    local deltaSeconds is (deltaAnomaly/360)*targetOrbit:period.
    print "Target Orbit Period: " + targetOrbit:period.
    print "Error in Seconds at Ownship Periapsis: " + deltaSeconds.

    local singleOrbitPeriod is ship:orbit:period + deltaSeconds.
    print "Single-Orbit Period: " + singleOrbitPeriod.
    local singleOrbitMajorAxis is 2 * ((body:mu * singleOrbitPeriod^2)/(4 * constant:pi^2))^(1/3).
    print "Single-Orbit Major Axis: " + singleOrbitMajorAxis.
    local singleOrbitApoapsis is singleOrbitMajorAxis - 2*body:radius - ship:periapsis.
    print "Single-Orbit Apoapsis: " + singleOrbitApoapsis.

    runPath("0:/src/scripts/transfer", apo, peri, singleOrbitApoapsis).
}