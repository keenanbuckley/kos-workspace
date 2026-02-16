// transfer_to.ks creates a timed Hohmann transfer node to a target body
// computes the phase angle and waits for the correct geometry
@lazyGlobal off.

parameter targetBody.
parameter captureAlt is -1.

runOncePath("0:/src/core/node").

// resolve string to body object
if targetBody:istype("String") {
    set targetBody to body(targetBody).
}

// validate: target must orbit the same parent as the vessel
if targetBody:orbit:body <> body {
    print "Error: " + targetBody:name + " does not orbit " + body:name + ".".
} else {
    // departure and target altitudes (above surface)
    local departAlt is orbit:semimajoraxis - body:radius.
    local targetAlt is targetBody:orbit:semimajoraxis - body:radius.

    // ideal phase angle for the transfer
    local idealPhase is hohmannPhaseAngle(departAlt, targetAlt, body).
    print "Ideal phase angle: " + round(idealPhase, 2) + " deg".

    // current phase angle: signed angle from vessel to target body
    // positive = target is ahead in the direction of orbital motion
    local vesPos is -body:position.
    local targetPos is targetBody:position - body:position.
    local orbNml is orbitNormal(vesPos, velocity:orbit).

    local currentPhase is signedAngle(vesPos, targetPos, -orbNml).
    set currentPhase to mod(currentPhase, 360).
    if currentPhase < 0 { set currentPhase to currentPhase + 360. }
    print "Current phase angle: " + round(currentPhase, 2) + " deg".

    // ETA to burn: how long until the phase angle matches
    local phaseRate is 360 / orbit:period - 360 / targetBody:orbit:period.
    local deltaPhase is mod(currentPhase - idealPhase, 360).
    if deltaPhase < 0 { set deltaPhase to deltaPhase + 360. }
    local burnEta is deltaPhase / phaseRate.
    print "Burn ETA: " + round(burnEta, 1) + " s (" + round(burnEta / orbit:period, 1) + " orbits)".

    // true anomaly at burn time (exact for circular orbits)
    local burnTA is mod(orbit:trueAnomaly + burnEta * 360 / orbit:period, 360).
    if burnTA < 0 { set burnTA to burnTA + 360. }

    // create node to raise apsis to target body altitude
    local nd is nodeChangeApsis(targetAlt, burnTA, orbit).

    if nd:istype("Node") {
        // adjust node time to the correct future orbit
        local targetTime is time:seconds + burnEta.
        local orbitsToAdd is round((targetTime - nd:time) / orbit:period).
        if orbitsToAdd > 0 {
            set nd to node(nd:time + orbitsToAdd * orbit:period, nd:radialout, nd:normal, nd:prograde).
        }
        local dv is sqrt(nd:prograde^2 + nd:radialout^2 + nd:normal^2).
        print "Transfer to " + targetBody:name
            + ": dv=" + round(dv, 2) + " m/s"
            + " at T+" + round(nd:time - time:seconds, 1) + "s".
        addNode(nd).
    } else {
        print "Failed to create transfer node.".
    }
}
