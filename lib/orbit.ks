function apoPeriToOrbit {
    parameter apo.
    parameter peri.
    parameter orbitBody.

    local semiMajor to apoPeriToSemiMajor(apo, peri, orbitBody).
    local ecc to semiMajorPeriToEcc(semiMajor, peri, orbitBody).
    return createOrbit(0, ecc, semiMajor, 0, 0, 0, 0, orbitBody).
}

function periEccToOrbit {
    parameter peri.
    parameter ecc.
    parameter orbitBody.

    local semiMajor to periEccToSemiMajor(peri, ecc, orbitBody).
    return createOrbit(0, ecc, semiMajor, 0, 0, 0, 0, orbitBody).
}

function apoPeriToSemiMajor {
    parameter apo.
    parameter peri.
    parameter orbitBody.

    return (0.5 * (apo + peri)) + orbitBody:radius.
}

function semiMajorPeriToEcc{
    parameter semiMajor.
    parameter peri.
    parameter orbitBody.

    return (semiMajor - peri - orbitBody:radius) / semiMajor.
}

function periEccToSemiMajor {
    parameter peri.
    parameter ecc.
    parameter orbitBody.

    if ecc = 1 { return 0. }
    return (peri + orbitBody:radius) / (1 - ecc).
}