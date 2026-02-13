// land.ks handles landing using engines
@lazyGlobal off.

parameter targetHeight is 0.
parameter targetVelocity is 10.

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

function targetEta {
    parameter thrust.
    parameter mfr.
    parameter g.
    parameter m0.
    parameter v0.
    parameter iter is 1.

    if iter = 0 {
        return -v0/(g-(thrust/m0)).
    } else {
        local t is targetEta(thrust, mfr, g, m0, v0, iter-1).
        return -vel(t, thrust, mfr, g, m0, v0)/accel(t, thrust, mfr, g, m0) - t.
    }
}


wait until ship:verticalspeed < 0.

sas off.
lock steering to srfRetrograde.

local lock thrust to ship:availableThrust*sin(arcTan2(-ship:verticalspeed, ship:groundspeed)).
local lock massFlowRate to availableMassFlowRate().
local lock landHeight to ship:geoposition:terrainheight.
if addons:tr:available and addons:tr:hasImpact {
    lock landHeight to addons:tr:impactPos:terrainheight.
}
local lock gravAcc to body:mu/((body:radius + landHeight)^2).

local tEta is abs(targetEta(thrust, massFlowRate, gravAcc, ship:mass, -ship:verticalspeed)).
local stoppingDist is dist(tEta, thrust, massFlowRate, gravAcc, ship:mass, -ship:verticalspeed).
until stoppingDist+targetHeight >= ship:altitude-landHeight {
    print "eta " + tEta at(0, 20).
    print "dst " + stoppingDist at(0, 21).
    print "tgt " + (ship:altitude - (landHeight+targetHeight)) at(0,22).
    print "vrt " + ship:verticalspeed at(0,23).
    print "hrz " + ship:groundspeed at(0,24).
    print "m0 " + ship:mass at(0,25).
    print "tst " + ship:availableThrust at(0,26).
    print "mfr " + availableMassFlowRate() at(0,27).
    set tEta to abs(targetEta(thrust, massFlowRate, gravAcc, ship:mass, -ship:verticalspeed)).
    set stoppingDist to dist(tEta, thrust, massFlowRate, gravAcc, ship:mass, -ship:verticalspeed).
}

lock throttle to 1.

wait until -ship:verticalspeed <= targetVelocity.

local lock weight to gravAcc * ship:mass.
lock throttle to throttleForThrust(weight)*min(-ship:verticalspeed/targetVelocity, 1).

wait until ship:verticalspeed >= -1.

unlock steering.
unlock throttle.

sas on.
set sasMode to "stability".
