// orbit.ks provides functions for creating orbit objects and calculating orbital parameters
@lazyGlobal off.

function apoPeriToOrbit {
    parameter apo.
    parameter peri.
    parameter orbitBody is body.

    local semiMajor to apsesToSemiMajor(apo, peri, orbitBody).
    local ecc to semiMajorPeriToEcc(semiMajor, peri, orbitBody).
    return createOrbit(0, ecc, semiMajor, 0, 0, 0, 0, orbitBody).
}

function periEccToOrbit {
    parameter peri.
    parameter ecc.
    parameter orbitBody is body.

    local semiMajor to periEccToSemiMajor(peri, ecc, orbitBody).
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

    return (apo + orbitBody:radius) / semiMajor.
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

function trueAnomalyToMeanAnomaly {
    parameter trueAnomaly.
    parameter ecc.

    local eccAnomaly to arcTan2(sqrt(1 - ecc^2) * sin(trueAnomaly), ecc + cos(trueAnomaly)).
    return eccAnomaly - ecc*sin(eccAnomaly).
}

// vis viva equation to get the orbital speed at a specified altitude and orbit semimajoraxis.
function visViva {
    declare parameter orbitingAltitude.
    declare parameter semiMajorAxis.
    declare parameter orbitingBody is body.

    local velocitySquared is orbitingBody:mu * ((2/(orbitingAltitude+orbitingBody:radius)) - (1/semiMajorAxis)).
    return sqrt(velocitySquared).
}

// equation to get the ratio between the radial and tangent velocities.
function tanFpa {
    parameter trueAnomaly.
    parameter ecc.

    return ecc * sin(trueAnomaly) / (1 + ecc * cos(trueAnomaly)).
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

