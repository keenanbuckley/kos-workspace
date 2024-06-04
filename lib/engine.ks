// engine

function throttleForThrust {
    parameter targetThrust.
    parameter minThrottle is 0.0.

    local staticThrust is 0.
    local dynamicThrust is 0.

    list engines in myEngines.
    for eng in myEngines {
        if eng:throttlelock {
            set staticThrust to staticThrust + eng:thrust.
        }
        else {
            set dynamicThrust to dynamicThrust + eng:availableThrust.
        }
    }.

    if staticFlameout {
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

function staticFlameout {
    list engines in myEngines.
    for eng in myEngines {
        if eng:throttlelock and eng:flameout {
            return true.
        }
    }.
    return false.
}