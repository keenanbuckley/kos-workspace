//node_utils

// vis viva equation to get the speed of a satellite at a specified altitude and orbit semimajoraxis.
function visViva {
    declare parameter orbitingAltitude.
    declare parameter semiMajorAxis.
    declare parameter orbitingBody is body.

    local velocitySquared is orbitingBody:mu * ((2/(orbitingAltitude+orbitingBody:radius)) - (1/semiMajorAxis)).
    return sqrt(velocitySquared).
}

// compute vis visa at apoapsis using apoapis and periapsis
function velocityApoapsis {
    declare parameter targetApoapsis.
    declare parameter targetPeriapsis.
    declare parameter orbitingBody is body.

    return visViva(targetApoapsis, (targetApoapsis+targetPeriapsis+(2*orbitingBody:radius))/2, orbitingBody).   
}

// compute vis visa at periapsis using apoapis and periapsis
function velocityPeriapsis {
    declare parameter targetApoapsis.
    declare parameter targetPeriapsis.
    declare parameter orbitingBody is body.

    return visViva(targetPeriapsis, (targetApoapsis+targetPeriapsis+(2*orbitingBody:radius))/2, orbitingBody).   
}

// generate a node at apoapsis to change the height of the periapsis
function nodeChangePeriapsis {
    declare parameter targetPeriapsis.
    declare parameter initialOrbit is orbit.

    // bound target to range
    // bound target apoapsis to range
    if not initialOrbit:hasNextPatch and targetPeriapsis < initialOrbit:body:soiRadius and targetPeriapsis > 0 {
        local currVel is velocityApoapsis(initialOrbit:apoapsis, initialOrbit:periapsis, initialOrbit:body).
        local targetVel is velocityApoapsis(initialOrbit:apoapsis, targetPeriapsis, initialOrbit:body).
        local deltaV is targetVel - currVel.
        return node(initialOrbit:eta:apoapsis + time:seconds, 0, 0, deltaV).
    }
    return -1.
}

// generate a node at periapsis to change the height of the apoapsis
function nodeChangeApoapsis {
    declare parameter targetApoapsis.
    declare parameter initialOrbit is orbit.

    // As of now, this function can only generate nodes at the periapsis
    // also bound target apoapsis to range
    if targetApoapsis < initialOrbit:body:soiradius and targetApoapsis > 0 {
        local currVel is velocityPeriapsis(initialOrbit:apoapsis, initialOrbit:periapsis, initialOrbit:body).
        local targetVel is velocityPeriapsis(targetApoapsis, initialOrbit:periapsis, initialOrbit:body).
        local deltaV is targetVel - currVel.
        return node(initialOrbit:eta:periapsis + time:seconds, 0, 0, deltaV).
    }
    return -1.
}