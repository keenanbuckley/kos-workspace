// burn.ks provides functions for performing calculations about upcoming burns
@lazyGlobal off.

function exhaustVelocity {
    parameter isp.

    return isp * constant:g0.
}

function rocketEquationDv {
    parameter startMass.
    parameter finalMass.
    parameter ev.

    // return change in velocity
    return ev * ln(startMass/finalMass).
}

function rocketEquationFinalMass {
    parameter startMass.
    parameter dv.
    parameter ev.

    // return final mass after dv
    return startMass / (constant:e^(dv/ev)).
}

function burnTime {
    parameter startMass.
    parameter dv.
    parameter ev.
    parameter flowRate.

    local dm is startMass - rocketEquationFinalMass(startMass, dv, ev).
    return dm / flowRate.
}

function meanBurnTime {
    parameter startMass.
    parameter dv.
    parameter ev.
    parameter flowRate.

    return burnTime(startMass, dv/2, ev, flowRate).
}
