// circular_escape.ks creates a directional escape node optimized for circular orbits
// computes the burn point so the exit velocity aligns with the desired
// direction in the parent body's frame (prograde or retrograde)
@lazyGlobal off.

parameter targetApo is -1.
parameter targetPeri is -1.
parameter safety is true.

runOncePath("0:/src/core/node").

local eccThreshold is 0.05.

if orbit:eccentricity >= 1 {
    print "Already on escape trajectory (ecc=" + round(orbit:eccentricity, 4) + ").".
} else if safety and orbit:eccentricity > eccThreshold {
    print "Orbit too eccentric (ecc=" + round(orbit:eccentricity, 4)
        + ", threshold=" + eccThreshold + ").".
    print "Use escape.ks for eccentric orbits or set safety=false.".
} else {
    local parentBody is body:orbit:body.
    local bodyAlt is body:orbit:semimajoraxis - parentBody:radius.

    if targetApo = -1 { set targetApo to bodyAlt. }
    if targetPeri = -1 { set targetPeri to bodyAlt. }

    print "Circular escape: " + body:name + " -> " + parentBody:name.
    print "Target orbit: apo=" + round(targetApo) + " peri=" + round(targetPeri).

    // === COMPUTE VSOI ===
    local targetSMA is apsesToSemiMajor(targetApo, targetPeri, parentBody).
    local targetVel is visViva(bodyAlt, targetSMA, parentBody).
    local bodyVel is visViva(bodyAlt, body:orbit:semimajoraxis, parentBody).
    local vSOI is abs(targetVel - bodyVel).

    // === COMPUTE BURN DV (via nodeEscape to avoid duplicating clamp/energy math) ===
    local escNode is nodeEscape(vSOI).
    local dv is escNode:prograde.
    local burnR is orbit:semimajoraxis.
    local soiR is body:soiRadius.
    local vBurn is dv + visViva(orbit:periapsis, orbit:semimajoraxis, body).

    // === ESCAPE ORBIT GEOMETRY ===
    local e is burnR * vBurn^2 / body:mu - 1.
    local p is burnR^2 * vBurn^2 / body:mu.

    // true anomaly at SOI crossing
    local nuExit is arccos((p / soiR - 1) / e).

    // flight path angle at exit
    local gamma is arctan2(e * sin(nuExit), 1 + e * cos(nuExit)).

    // exit velocity direction relative to periapsis direction
    local exitVelAngle is nuExit + 90 - gamma.

    // === ESCAPE TIME (periapsis to SOI crossing) ===
    local aEsc is burnR / (1 - e).
    local escapeTime is 0.
    if e < 1 {
        // elliptical: Kepler's equation
        local cosEA is (e + cos(nuExit)) / (1 + e * cos(nuExit)).
        local eccAnom is arccos(cosEA).
        local M_rad is eccAnom * constant:degtorad - e * sin(eccAnom).
        set escapeTime to M_rad * sqrt(aEsc^3 / body:mu).
    } else {
        // hyperbolic: hyperbolic Kepler's equation
        local coshH is (e + cos(nuExit)) / (1 + e * cos(nuExit)).
        local sinhH is sqrt(coshH^2 - 1).
        local H is ln(coshH + sinhH).
        local M_h is e * sinhH - H.
        set escapeTime to M_h * sqrt((-aEsc)^3 / body:mu).
    }

    // body's angular rate in parent orbit (degrees per second)
    local bodyRate is 360 / body:orbit:period.

    // === ESCAPE DIRECTION ===
    // 0 = prograde (raise parent apo), 180 = retrograde (lower parent peri)
    local escapeDir is choose 0 if targetVel >= bodyVel else 180.

    // === BURN ANGLE WITH BODY ROTATION CORRECTION ===
    // body's prograde direction in parent frame
    local bodyPro is body:orbit:velocity:orbit:normalized.
    // vessel position relative to body
    local vesPos is (-body:position):normalized.
    // orbital normal (angular momentum direction)
    local orbNormal is vcrs(vesPos, velocity:orbit):normalized.

    // project body's prograde onto the vessel's orbital plane
    local bodyProPlane is bodyPro - vdot(bodyPro, orbNormal) * orbNormal.
    set bodyProPlane to bodyProPlane:normalized.

    // current vessel position angle from body's prograde (in orbital plane)
    local currentAngle is arctan2(
        vdot(vcrs(bodyProPlane, vesPos), orbNormal),
        vdot(vesPos, bodyProPlane)).

    // iterative burn angle: account for body rotation during wait + escape
    // iteration 1: initial estimate without wait-time rotation
    local burnAngle is escapeDir - exitVelAngle + escapeTime * bodyRate.
    until burnAngle >= 0 { set burnAngle to burnAngle + 360. }
    until burnAngle < 360 { set burnAngle to burnAngle - 360. }

    // minimum 1° offset prevents placing a node at the current position
    local burnOffset is burnAngle - currentAngle.
    until burnOffset > 1 { set burnOffset to burnOffset + 360. }
    local burnEta is burnOffset / 360 * orbit:period.

    // iteration 2: include wait-time rotation
    local totalRotation is (burnEta + escapeTime) * bodyRate.
    set burnAngle to escapeDir - exitVelAngle + totalRotation.
    until burnAngle >= 0 { set burnAngle to burnAngle + 360. }
    until burnAngle < 360 { set burnAngle to burnAngle - 360. }

    set burnOffset to burnAngle - currentAngle.
    until burnOffset > 1 { set burnOffset to burnOffset + 360. }
    set burnEta to burnOffset / 360 * orbit:period.

    // node placement
    local nodeTime is time:seconds + burnEta.
    if hasNode {
        until nodeTime > allNodes[allNodes:length-1]:time {
            set nodeTime to nodeTime + orbit:period.
        }
    }

    local dirStr is choose "prograde" if escapeDir = 0 else "retrograde".
    print "dv=" + round(dv, 2) + " m/s " + dirStr.
    print "burn_eta=" + round(burnEta, 1) + "s"
        + " esc_time=" + round(escapeTime, 1) + "s".

    local nd is node(nodeTime, 0, 0, dv).
    addNode(nd).
}
