// burn.ks provides functions for performing calculations about upcoming burns
@lazyGlobal off.

function exhaust_velocity {
    parameter isp.
    
    return isp * constant:g0.
}

function rocket_equation_dv {
    parameter start_mass.
    parameter final_mass.
    parameter ev.

    // return change in velocity
    return ev * ln(start_mass/final_mass).
}

function rocket_equation_final_mass {
    parameter start_mass.
    parameter dv.
    parameter ev.

    // return final mass after dv
    return start_mass / (constant:e^(dv/ev)).
}

function burn_time {
    parameter start_mass.
    parameter dv.
    parameter ev.
    parameter flow_rate.

    local dm is start_mass - rocket_equation_final_mass(start_mass, dv, ev).
    return dm / flow_rate.
}

function mean_burn_time {
    parameter start_mass.
    parameter dv.
    parameter ev.
    parameter flow_rate.

    return burn_time(start_mass, dv/2, ev, flow_rate).
}