// engine.ks provides functions for performing calculations about engines
@lazyGlobal off.

function staticFlameout {
    local myEngines is list().
    list engines in myEngines.
    for eng in myEngines {
        if eng:throttlelock and eng:flameout {
            return true.
        }
    }.
    return false.
}

function throttleForThrust {
    parameter targetThrust.
    parameter minThrottle is 0.0.

    local staticThrust is 0.
    local dynamicThrust is 0.

    local myEngines is list().
    list engines in myEngines.
    for eng in myEngines {
        if eng:throttlelock {
            set staticThrust to staticThrust + eng:thrust.
        }
        else {
            set dynamicThrust to dynamicThrust + eng:availableThrust.
        }
    }.

    if staticFlameout() {
        local adjThrottle is targetThrust / dynamicThrust.
        return min(max(minThrottle, adjThrottle), 1.0).
    }
    else if dynamicThrust > 0 {
        local adjThrottle is (targetThrust - staticThrust) / dynamicThrust.
        return min(max(minThrottle, adjThrottle), 1.0).
    } else {
        return minThrottle.
    }    
}

function engineFlameout {
    local myEngines is list().
    list engines in myEngines.
    for eng in myEngines {
        if eng:flameout {
            return true.
        }
    }.
    return false.
}

function available_mass_flow_rate {
    local myEngines is list().
    list engines in myEngines.
    local flow_rate_sum is 0.
    for eng in myEngines {
        if eng:availableThrust > 0 {
            set flow_rate_sum to flow_rate_sum + eng:maxMassFlow*eng:thrustLimit/100.
        }
    }.
    return flow_rate_sum.
}

function available_mass_flow_rate_at {
    parameter pressure.

    local myEngines is list().
    list engines in myEngines.
    local flow_rate_sum is 0.
    for eng in myEngines {
        set flow_rate_sum to flow_rate_sum + eng:availableThrustAt(pressure)/(eng:ispAt(pressure)*constant:g0).
    }.
    return flow_rate_sum.
}