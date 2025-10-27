// this script handles landing using engines

parameter target_height is 0.
parameter target_velocity is 10.

runOncePath("0:/src/core/engine").

function accel {
    parameter t.
    parameter thrust.
    parameter mfr.
    parameter g.
    parameter m0.

    set t to min(t, (m0 - ship:drymass)/mfr).
    return g - thrust/(m0 - mfr*t).
}

function vel {
    parameter t.
    parameter thrust.
    parameter mfr.
    parameter g.
    parameter m0.
    parameter v0.

    set t to min(t, (m0 - ship:drymass)/mfr).
    return v0 + g*t + (thrust/mfr)*ln(1 - (mfr*t)/m0).
}

function dist {
    parameter t.
    parameter thrust.
    parameter mfr.
    parameter g.
    parameter m0.
    parameter v0.

    set t to min(t, (m0 - ship:drymass)/mfr).
    return v0*t + 0.5*g*t^2 - (thrust/mfr^2)*(mfr*t + ln(1 - (mfr*t)/m0)*(m0 - mfr*t)).
}

function target_eta {
    parameter thrust.
    parameter mfr.
    parameter g.
    parameter m0.
    parameter v0.
    parameter iter is 1.

    if iter = 0 {
        return -v0/(g-(thrust/m0)).
    } else {
        local t is target_eta(thrust, mfr, g, m0, v0, iter-1).
        return -vel(t, thrust, mfr, g, m0, v0)/accel(t, thrust, mfr, g, m0) - t.
    }
}


wait until ship:verticalspeed < 0.

sas off.
lock steering to srfRetrograde.

local lock thrust to ship:availableThrust*sin(arcTan2(-ship:verticalspeed, ship:groundspeed)).
local mass_flow_rate is available_mass_flow_rate().
local lock land_height to ship:geoposition:terrainheight.
if addons:tr:available and addons:tr:hasImpact {
    lock land_height to addons:tr:impactPos:terrainheight.
}
local gravAcc is body:mu/((body:radius + land_height)^2).

local t_eta is abs(target_eta(thrust, mass_flow_rate, gravAcc, ship:mass, -ship:verticalspeed)).
local stopping_dist is dist(t_eta, thrust, mass_flow_rate, gravAcc, ship:mass, -ship:verticalspeed).
until stopping_dist+target_height >= ship:altitude-land_height {
    print "eta " + t_eta at(0, 20).
    print "dst " + stopping_dist at(0, 21).
    print "tgt " + (ship:altitude - (land_height+target_height)) at(0,22).
    print "vrt " + ship:verticalspeed at(0,23).
    print "hrz " + ship:groundspeed at(0,24).
    print "m0 " + ship:mass at(0,25).
    print "tst " + ship:availableThrust at(0,26).
    print "mfr " + available_mass_flow_rate() at(0,27).
    set t_eta to abs(target_eta(thrust, mass_flow_rate, gravAcc, ship:mass, -ship:verticalspeed)).
    set stopping_dist to dist(t_eta, thrust, mass_flow_rate, gravAcc, ship:mass, -ship:verticalspeed).
}

lock throttle to 1.

wait until -ship:verticalspeed <= target_velocity.

local lock weight to gravAcc * ship:mass.
lock throttle to throttleForThrust(weight)*min(-ship:verticalspeed/target_velocity, 1).

wait until ship:verticalspeed >= -1.

unlock throttle.

sas on.
set sasMode to "stability".