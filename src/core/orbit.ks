// orbit.ks provides functions for creating orbit objects and calculating orbital parameters
@lazyGlobal off.

runOncePath("0:/src/core/trig").

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

    if ecc < 1 {
        local eccAnomaly is arcTan2(sqrt(1 - ecc^2) * sin(trueAnomaly), ecc + cos(trueAnomaly)).
        return eccAnomaly - constant:radtodeg*ecc*sin(eccAnomaly).
    } else {
        local coshH is (ecc + cos(trueAnomaly)) / (1 + ecc * cos(trueAnomaly)).
        local H is acosh(coshH).
        if sin(trueAnomaly) < 0 { set H to -H. }
        local M_h is ecc * sinh(H) - H.
        return M_h * constant:radtodeg.
    }
}

// time from now until the vessel reaches a given true anomaly
function etaToTrueAnomaly {
    parameter trueAnomaly.
    parameter initialOrbit is orbit.

    local ecc is initialOrbit:eccentricity.
    local result is 0.

    if ecc < 1 {
        set result to (initialOrbit:period / 360)
            * trueAnomalyToMeanAnomaly(trueAnomaly, ecc)
            + initialOrbit:eta:periapsis.
        set result to mod(result, initialOrbit:period).
        if result < 0 { set result to result + initialOrbit:period. }
    } else {
        local coshH is (ecc + cos(trueAnomaly)) / (1 + ecc * cos(trueAnomaly)).
        local H is acosh(coshH).
        if sin(trueAnomaly) < 0 { set H to -H. }
        local M_h is ecc * sinh(H) - H.
        set result to M_h * sqrt((-initialOrbit:semimajoraxis)^3
            / initialOrbit:body:mu) + initialOrbit:eta:periapsis.
    }

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

// converts from TZN [tangential, zenith, normal] to RNP [radialout, normal, prograde]
// rotation by flight path angle gamma around the normal axis
function tznToRnp {
    parameter tznVec.
    parameter trueAnomaly.
    parameter ecc.

    local tFpa is tanFpa(trueAnomaly, ecc).
    local cosG is 1 / sqrt(tFpa^2 + 1).
    local sinG is tFpa * cosG.

    return V(
        -tznVec:x * sinG + tznVec:y * cosG,
        tznVec:z,
        tznVec:x * cosG + tznVec:y * sinG
    ).
}

// converts from RNP [radialout, normal, prograde] to TZN [tangential, zenith, normal]
// inverse rotation by flight path angle gamma around the normal axis
function rnpToTzn {
    parameter rnpVec.
    parameter trueAnomaly.
    parameter ecc.

    local tFpa is tanFpa(trueAnomaly, ecc).
    local cosG is 1 / sqrt(tFpa^2 + 1).
    local sinG is tFpa * cosG.

    return V(
        rnpVec:z * cosG - rnpVec:x * sinG,
        rnpVec:z * sinG + rnpVec:x * cosG,
        rnpVec:y
    ).
}

// converts from TZN [tangential, zenith, normal] to PQW [periapsis, perpendicular, angular momentum]
// rotation by true anomaly around the normal axis
function tznToPqw {
    parameter tznVec.
    parameter trueAnomaly.

    return V(
        -tznVec:x * sin(trueAnomaly) + tznVec:y * cos(trueAnomaly),
        tznVec:x * cos(trueAnomaly) + tznVec:y * sin(trueAnomaly),
        tznVec:z
    ).
}

// converts from PQW [periapsis, perpendicular, angular momentum] to TZN [tangential, zenith, normal]
// inverse rotation by true anomaly around the normal axis
function pqwToTzn {
    parameter pqwVec.
    parameter trueAnomaly.

    return V(
        -pqwVec:x * sin(trueAnomaly) + pqwVec:y * cos(trueAnomaly),
        pqwVec:x * cos(trueAnomaly) + pqwVec:y * sin(trueAnomaly),
        pqwVec:z
    ).
}

// converts from TZN [tangential, zenith, normal] to the kOS raw (global inertial) frame
function tznToRaw {
    parameter tznVec.
    parameter pos is -body:position.
    parameter vel is velocity:orbit.

    local zHat is pos:normalized.
    local nHat is orbitNormal(pos, vel).
    local tHat is vcrs(nHat, zHat):normalized.

    return tznVec:x * tHat + tznVec:y * zHat + tznVec:z * nHat.
}

// converts from the kOS raw (global inertial) frame to TZN [tangential, zenith, normal]
function rawToTzn {
    parameter rawVec.
    parameter pos is -body:position.
    parameter vel is velocity:orbit.

    local zHat is pos:normalized.
    local nHat is orbitNormal(pos, vel).
    local tHat is vcrs(nHat, zHat):normalized.

    return V(vdot(rawVec, tHat), vdot(rawVec, zHat), vdot(rawVec, nHat)).
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

