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

    if ecc < 1 {
        local X is (sqrt(1 - ecc^2) * sin(trueAnomaly)) / (1 + ecc*cos(trueAnomaly)).
        return sqrt(semiMajorAxis^3 / orbitingBody:mu) * (constant:degtorad*arcSin(X) - ecc*X).
    } else {
        local coshH is (ecc + cos(trueAnomaly)) / (1 + ecc * cos(trueAnomaly)).
        local H is acosh(coshH).
        if sin(trueAnomaly) < 0 { set H to -H. }
        local M_h is ecc * sinh(H) - H.
        return M_h * sqrt((-semiMajorAxis)^3 / orbitingBody:mu).
    }
}

// generate a node at apoapsis to change the height of the periapsis
function nodeChangePeriapsis {
    parameter targetPeriapsis.
    parameter initialOrbit is orbit.
    parameter safety is true.

    if initialOrbit:eccentricity >= 1 { return -1. }

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

    if initialOrbit:eccentricity >= 1 { return -1. }

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
        local orbitingAltitude is altitudeAtTrueAnomaly(trueAnomaly, initialOrbit).
        local targetEcc is apsesToEcc(orbitingAltitude, targetApsis, initialOrbit:body).
        local targetTrueAnomaly is choose 0 if targetApsis > orbitingAltitude else 180.

        local currSpeed is visViva(orbitingAltitude, initialOrbit:semimajoraxis, initialOrbit:body).
        local targetSpeed is visViva(orbitingAltitude, apsesToSemiMajor(orbitingAltitude, targetApsis, initialOrbit:body), initialOrbit:body).

        local currVel is rnpToTzn(V(0,0,currSpeed), trueAnomaly, initialOrbit:eccentricity).
        local targetVel is rnpToTzn(V(0,0,targetSpeed), targetTrueAnomaly, targetEcc).

        local deltaV is tznToRnp(targetVel - currVel, trueAnomaly, initialOrbit:eccentricity).
        local nodeEta is etaToTrueAnomaly(trueAnomaly, initialOrbit).
        local nodeTime is nodeEta + time:seconds.
        if initialOrbit:eccentricity < 1 {
            set nodeTime to scheduleAfterNodes(nodeTime, initialOrbit:period).
        }
        return node(nodeTime, deltaV:x, deltaV:y, deltaV:z).
    }
    return -1.
}

// generate a prograde node at periapsis to escape the current SOI
// vSOI is the desired speed relative to the body at the SOI boundary
function nodeEscape {
    parameter vSOI is 0.
    parameter initialOrbit is orbit.

    if initialOrbit:eccentricity >= 1 { return -1. }

    local burnAlt is initialOrbit:periapsis.
    local burnR is burnAlt + initialOrbit:body:radius.
    local soiR is initialOrbit:body:soiRadius.
    // minimum SOI boundary speed due to angular momentum constraint
    // orbit must cross SOI, not just touch it, so use 0.99*soiR as effective boundary
    local vSOIMin is sqrt(2 * initialOrbit:body:mu * burnR / (soiR * 0.99 * (soiR * 0.99 + burnR))).
    if vSOI < vSOIMin { set vSOI to vSOIMin. }
    local vCurrent is velocityPeriapsis(initialOrbit:apoapsis, initialOrbit:periapsis, initialOrbit:body).
    local vBurn is sqrt(vSOI^2 + 2 * initialOrbit:body:mu * (1/burnR - 1/soiR)).
    local dv is vBurn - vCurrent.

    local nodeTime is scheduleAfterNodes(initialOrbit:eta:periapsis + time:seconds, initialOrbit:period).
    return node(nodeTime, 0, 0, dv).
}

// generate a node to match the orbital plane of a target orbit
function nodeChangePlane {
    parameter targetOrbit.
    parameter initialOrbit is orbit.

    if initialOrbit:eccentricity >= 1 { return -1. }
    if initialOrbit:body <> targetOrbit:body { return -1. }

    // vessel orbital normal
    local vesPos is -body:position.
    local orbNormal is orbitNormal(vesPos, velocity:orbit).

    // target orbital normal
    local targetPos is targetOrbit:position - body:position.
    local targetVel is targetOrbit:velocity:orbit.
    local targetNormal is orbitNormal(targetPos, targetVel).

    // relative inclination between the two planes
    local relInc is vang(orbNormal, targetNormal).
    if relInc < 0.01 { return -1. }

    // line of nodes: intersection of the two orbital planes
    local nodeDir is vcrs(orbNormal, targetNormal):normalized.

    // signed angle from vessel position to nodeDir
    local vesPosNorm is vesPos:normalized.
    local posToNode is arctan2(
        vdot(vcrs(vesPosNorm, nodeDir), orbNormal),
        vdot(vesPosNorm, nodeDir)).

    // true anomaly at each node crossing
    local taNode is mod(initialOrbit:trueAnomaly + posToNode, 360).
    if taNode < 0 { set taNode to taNode + 360. }
    local taOpposite is mod(taNode + 180, 360).

    // pick whichever node comes sooner
    local etaNode is etaToTrueAnomaly(taNode, initialOrbit).
    local etaOpposite is etaToTrueAnomaly(taOpposite, initialOrbit).

    local burnTA is taNode.
    local burnEta is etaNode.
    local burnAtNodeDir is true.
    if etaOpposite < etaNode {
        set burnTA to taOpposite.
        set burnEta to etaOpposite.
        set burnAtNodeDir to false.
    }

    local burnTime is scheduleAfterNodes(time:seconds + burnEta, initialOrbit:period).

    // delta-v: rotate velocity by relInc around the zenith axis in TZN
    local burnAlt is altitudeAtTrueAnomaly(burnTA, initialOrbit).
    local burnSpeed is visViva(burnAlt, initialOrbit:semimajoraxis, initialOrbit:body).
    local currTZN is rnpToTzn(V(0, 0, burnSpeed), burnTA, initialOrbit:eccentricity).

    // sign = -1 at nodeDir, +1 at opposite
    // (kOS positive normal = north = opposite of orbNormal)
    local sign is choose -1 if burnAtNodeDir else 1.
    local dT is currTZN:x * (cos(relInc) - 1).
    local dN is sign * currTZN:x * sin(relInc).
    local dvRNP is tznToRnp(V(dT, 0, dN), burnTA, initialOrbit:eccentricity).

    print "Plane change: " + round(relInc, 2) + " deg".
    print "dv=" + round(dvRNP:mag, 2) + " m/s"
        + " (rad=" + round(dvRNP:x, 2)
        + " nrm=" + round(dvRNP:y, 2)
        + " pro=" + round(dvRNP:z, 2) + ")".

    return node(burnTime, dvRNP:x, dvRNP:y, dvRNP:z).
}

// push node time past any existing nodes by adding orbital periods
function scheduleAfterNodes {
    parameter nodeTime.
    parameter period.

    if hasNode and period < 2^50 {
        until nodeTime > allNodes[allNodes:length-1]:time {
            set nodeTime to nodeTime + period.
        }
    }
    return nodeTime.
}

// add a node if delta-v is high enough
function addNode {
    parameter newNode.
    parameter thres is 1e-3.

    if newNode:istype("Node") {
        local prevCount is allNodes:length.
        add newNode.
        wait 0.
        if allNodes:length <= prevCount {
            print "WARNING: node add failed (time may precede existing node)".
        } else if allNodes[allNodes:length-1]:deltav:mag < thres {
            remove newNode.
            print "node has low dv, removing".
        } else {
            print "added node with dv of " + round(allNodes[allNodes:length-1]:deltav:mag, 3).
        }
    } else {
        print "failed".
    }
}