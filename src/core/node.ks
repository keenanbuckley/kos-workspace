// node.ks provides functions for performing calculations to plan maneuver nodes
@lazyGlobal off.

runOncePath("0:/src/core/orbit").

// compute orbital speed at apoapsis using apoapis and periapsis
function velocityApoapsis {
    parameter targetApoapsis.
    parameter targetPeriapsis.
    parameter orbitingBody is body.

    return visViva(targetApoapsis, (targetApoapsis+targetPeriapsis+(2*orbitingBody:radius))/2, orbitingBody).   
}

// compute orbital speed at periapsis using apoapis and periapsis
function velocityPeriapsis {
    parameter targetApoapsis.
    parameter targetPeriapsis.
    parameter orbitingBody is body.

    return visViva(targetPeriapsis, (targetApoapsis+targetPeriapsis+(2*orbitingBody:radius))/2, orbitingBody).   
}

// get the velocity of a ship using cosign of the flight path angle, altitude, and an apsis
function velocityFlightPathAngle {
    parameter cfpa.   // flight path angle
    parameter obtAlt. // orbiting altitude
    parameter apsis.
    parameter orbitingBody is body.

    // print(apsis^2 / (obtAlt*(apsis + obtAlt*cfpa)*(apsis - obtAlt*cfpa))).

    if apsis < obtAlt*cfpa or apsis > obtAlt { // avoid undefined behavior
        return sqrt((2*orbitingBody:mu*apsis*(apsis - obtAlt)) / (obtAlt*(apsis + obtAlt*cfpa)*(apsis - obtAlt*cfpa))).
    }
    return -1.
}

// get the cosign of the flight path angle using velocity, altitude, semiMajorAxis, and eccentricity
function cfpaVelocity {
    parameter vel.
    parameter obtAlt. // orbiting altitude
    parameter semiMajorAxis.
    parameter ecc.
    parameter orbitingBody is body.

    return sqrt(orbitingBody:mu * (1 - ecc^2) * semiMajorAxis) / (obtAlt*vel).
}

// returns the time past the periapsis of the true anomaly
function timeTrueAnomaly {
    parameter trueAnomaly.
    parameter semiMajorAxis.
    parameter ecc.
    parameter orbitingBody is body.

    local X is (sqrt(1 - ecc^2) * sin(trueAnomaly)) / (1 + ecc*cos(trueAnomaly)).
    return sqrt(semiMajorAxis^3 / orbitingBody:mu) * (arcSin(X) - ecc*X).
}

// generate a node at apoapsis to change the height of the periapsis
function nodeChangePeriapsis {
    parameter targetPeriapsis.
    parameter initialOrbit is orbit.
    parameter safety is true.

    // bound target to range
    // bound target apoapsis to range
    if not initialOrbit:hasNextPatch and (not safety or (targetPeriapsis < initialOrbit:body:soiRadius and targetPeriapsis > 0)) {
        local currVel is velocityApoapsis(initialOrbit:apoapsis, initialOrbit:periapsis, initialOrbit:body).
        local targetVel is velocityApoapsis(initialOrbit:apoapsis, targetPeriapsis, initialOrbit:body).
        local deltaV is targetVel - currVel.
        return node(initialOrbit:eta:apoapsis + time:seconds, 0, 0, deltaV).
    }
    return -1.
}

// generate a node at periapsis to change the height of the apoapsis
function nodeChangeApoapsis {
    parameter targetApoapsis.
    parameter initialOrbit is orbit.
    parameter safety is true.

    // As of now, this function can only generate nodes at the periapsis
    // also bound target apoapsis to range
    if not safety or (targetApoapsis < initialOrbit:body:soiradius and targetApoapsis > 0) {
        local currVel is velocityPeriapsis(initialOrbit:apoapsis, initialOrbit:periapsis, initialOrbit:body).
        local targetVel is velocityPeriapsis(targetApoapsis, initialOrbit:periapsis, initialOrbit:body).
        local deltaV is targetVel - currVel.
        return node(initialOrbit:eta:periapsis + time:seconds, 0, 0, deltaV).
    }
    return -1.
}

// generate a node at target true anomaly to change the height of an apsis
function nodeChangeApsis {
    parameter targetApsis.
    parameter trueAnomaly.
    parameter initialOrbit is orbit.
    parameter safety is true.

    // bound target apsis to range
    if not safety or (targetApsis < initialOrbit:body:soiradius and targetApsis > 0) {
        local orbitingAltitude is initialOrbit:semimajoraxis * (1 - initialOrbit:eccentricity^2) / (1 + initialOrbit:eccentricity*cos(trueAnomaly)) - initialOrbit:body:radius.
        local targetEcc is apsesToEcc(orbitingAltitude, targetApsis, initialOrbit:body).
        local targetTrueAnomaly is choose 0 if targetApsis > orbitingAltitude else 180.

        local currSpeed is visViva(orbitingAltitude, initialOrbit:semimajoraxis, initialOrbit:body).
        local targetSpeed is visViva(orbitingAltitude, apsesToSemiMajor(orbitingAltitude, targetApsis, initialOrbit:body), initialOrbit:body).

        local currVel is prnToTrn(V(currSpeed,0,0), trueAnomaly, initialOrbit:eccentricity).
        local targetVel is prnToTrn(V(targetSpeed,0,0), targetTrueAnomaly, targetEcc).

        local deltaV is TrnToPrn(targetVel - currVel, targetTrueAnomaly, targetEcc).
        local nodeEta is (initialOrbit:period / 360) * trueAnomalyToMeanAnomaly(trueAnomaly, initialOrbit:eccentricity) + initialOrbit:eta:periapsis.
        until nodeEta < initialOrbit:period {
            set nodeEta to nodeEta - initialOrbit:period.
        }
        return node(nodeEta + time:seconds, deltaV:y, deltaV:z, deltaV:x).
    }
    return -1.
}

// add a node if delta-v is high enough
function addNode {
    parameter newNode.
    parameter thres is 1e-3.

    if newNode:istype("Node") {
        add newNode.
        if abs(allNodes[allNodes:length-1]:prograde) < thres {
            remove newNode.
            print "node has low dv, removing".
        } else {
            print "added node with dv of " + allNodes[allNodes:length-1]:prograde.
        }
    } else {
        print "failed".
    }
}