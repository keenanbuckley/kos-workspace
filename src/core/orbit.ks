// orbit.ks provides functions for creating orbit objects and calculating orbital parameters
@lazyGlobal off.

function apoPeriToOrbit {
    parameter apo.
    parameter peri.
    parameter orbitBody is body.

    local semiMajor is apsesToSemiMajor(apo, peri, orbitBody).
    local ecc is semiMajorPeriToEcc(semiMajor, peri, orbitBody).
    return createOrbit(0, ecc, semiMajor, 0, 0, 0, 0, orbitBody).
}

function periEccToOrbit {
    parameter peri.
    parameter ecc.
    parameter orbitBody is body.

    local semiMajor is periEccToSemiMajor(peri, ecc, orbitBody).
    return createOrbit(0, ecc, semiMajor, 0, 0, 0, 0, orbitBody).
}

function apsesToSemiMajor {
    parameter apsis1.
    parameter apsis2.
    parameter orbitBody is body.

    return 0.5 * (apsis1 + apsis2) + orbitBody:radius.
}

function semiMajorPeriToEcc{
    parameter semiMajor.
    parameter peri.
    parameter orbitBody is body.

    return (semiMajor - peri - orbitBody:radius) / semiMajor.
}

function semiMajorApoToEcc{
    parameter semiMajor.
    parameter apo.
    parameter orbitBody is body.

    return (apo + orbitBody:radius) / semiMajor - 1.
}

function apoPeriToEcc {
    parameter apo.
    parameter peri.
    parameter orbitBody is body.

    return (apo - peri) / (apo + peri + orbitBody:radius + orbitBody:radius).
}

function apsesToEcc {
    parameter apsis1.
    parameter apsis2.
    parameter orbitBody is body.

    return abs((apsis2 - apsis1) / (apsis1 + apsis2 + orbitBody:radius + orbitBody:radius)).
}

function periEccToSemiMajor {
    parameter peri.
    parameter ecc.
    parameter orbitBody is body.

    if ecc = 1 { return 0. }
    return (peri + orbitBody:radius) / (1 - ecc).
}

// altitude above body surface at a given true anomaly
function altitudeAtTrueAnomaly {
    parameter trueAnomaly.
    parameter initialOrbit is orbit.

    return initialOrbit:semimajoraxis * (1 - initialOrbit:eccentricity^2)
        / (1 + initialOrbit:eccentricity * cos(trueAnomaly))
        - initialOrbit:body:radius.
}

function trueAnomalyToMeanAnomaly {
    parameter trueAnomaly.
    parameter ecc.

    local eccAnomaly is arcTan2(sqrt(1 - ecc^2) * sin(trueAnomaly), ecc + cos(trueAnomaly)).
    return eccAnomaly - constant:radtodeg*ecc*sin(eccAnomaly).
}

// time from now until the vessel reaches a given true anomaly
function etaToTrueAnomaly {
    parameter trueAnomaly.
    parameter initialOrbit is orbit.

    local result is (initialOrbit:period / 360)
        * trueAnomalyToMeanAnomaly(trueAnomaly, initialOrbit:eccentricity)
        + initialOrbit:eta:periapsis.
    set result to mod(result, initialOrbit:period).
    if result < 0 { set result to result + initialOrbit:period. }
    return result.
}

// vis viva equation to get the orbital speed at a specified altitude and orbit semimajoraxis.
function visViva {
    parameter orbitingAltitude.
    parameter semiMajorAxis.
    parameter orbitingBody is body.

    local velocitySquared is orbitingBody:mu * ((2/(orbitingAltitude+orbitingBody:radius)) - (1/semiMajorAxis)).
    return sqrt(velocitySquared).
}

// equation to get the ratio between the radial and tangent velocities.
function tanFpa {
    parameter trueAnomaly.
    parameter ecc.

    return ecc * sin(trueAnomaly) / (1 + ecc * cos(trueAnomaly)).
}

// orbital angular momentum direction (plane normal)
function orbitNormal {
    parameter pos.
    parameter vel.

    return vcrs(pos, vel):normalized.
}

// signed angle (degrees) from fromVec to toVec around normalVec
// positive = toVec is counter-clockwise from fromVec when viewed from normalVec
function signedAngle {
    parameter fromVec.
    parameter toVec.
    parameter normalVec.

    return arctan2(
        vdot(vcrs(fromVec:normalized, toVec:normalized), normalVec:normalized),
        vdot(fromVec:normalized, toVec:normalized)).
}

// ideal phase angle (degrees) for a Hohmann transfer between two circular orbits
// departAlt and targetAlt are altitudes above the parent body surface
function hohmannPhaseAngle {
    parameter departAlt.
    parameter targetAlt.
    parameter parentBody is body.

    local r1 is departAlt + parentBody:radius.
    local r2 is targetAlt + parentBody:radius.
    local transferSMA is (r1 + r2) / 2.
    local transferTime is constant:pi * sqrt(transferSMA^3 / parentBody:mu).
    local targetPeriod is 2 * constant:pi * sqrt(r2^3 / parentBody:mu).
    return 180 - (360 / targetPeriod) * transferTime.
}

// converts from [prograde, radial, normal] space to [tangent, radial, normal] space
function prnToTrn {
    parameter prnVec.
    parameter trueAnomaly.
    parameter ecc.

    local tFpa is tanFpa(trueAnomaly, ecc).
    local progradeTan is prnVec:x / sqrt(tFpa^2 + 1).
    local progradeRad is tFpa * progradeTan.

    return V(progradeTan, progradeRad + prnVec:y, prnVec:z).
}

// converts from [tangent, radial, normal] space to [prograde, radial, normal] space
function TrnToPrn {
    parameter trnVec.
    parameter trueAnomaly.
    parameter ecc.

    local tFpa is tanFpa(trueAnomaly, ecc).

    return V(trnVec:x * sqrt(tFpa^2 + 1), trnVec:y - tFpa * trnVec:x, trnVec:z).
}

// computes the compass heading for a launch into a target orbital inclination,
// corrected for the body's surface rotation velocity.
function launchAzimuth {
    parameter targetInclination.
    parameter targetAltitude is 80000.
    parameter launchLatitude is ship:geoPosition:lat.
    parameter orbitBody is body.

    // Inertial azimuth from spherical trig: cos(i) = cos(lat) * sin(az)
    local sinAz is cos(targetInclination) / cos(launchLatitude).
    local inertialAzimuth is arcsin(min(1, max(-1, sinAz))).

    // Orbital velocity for a circular orbit at target altitude (vis-viva)
    local targetRadius is orbitBody:radius + targetAltitude.
    local vOrbit is sqrt(orbitBody:mu / targetRadius).

    // Surface rotation velocity at launch latitude
    local vRot is (2 * constant:pi * orbitBody:radius * cos(launchLatitude)) / orbitBody:rotationPeriod.

    // Subtract rotation from inertial velocity to get surface-relative heading
    local vXrot is vOrbit * sin(inertialAzimuth) - vRot.
    local vYrot is vOrbit * cos(inertialAzimuth).

    local azimuth is arctan2(vXrot, vYrot).
    if azimuth < 0 { set azimuth to azimuth + 360. }
    return azimuth.
}

