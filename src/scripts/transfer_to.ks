// transfer_to.ks — Hohmann transfer with encounter periapsis tuning
//   captureAlt = -1 (default): impact trajectory (minimize periapsis)
//   captureAlt = 0: graze body surface
//   captureAlt > 0: target periapsis at specified altitude
@lazyGlobal off.

parameter targetBody.
parameter captureAlt is -1.

runOncePath("0:/src/core/node").

if targetBody:istype("String") {
    set targetBody to body(targetBody).
}

if targetBody:orbit:body <> body {
    print "Error: " + targetBody:name + " does not orbit " + body:name + ".".
} else {
    createTransferNode(targetBody, captureAlt).
}

function createTransferNode {
    parameter tgtBody.
    parameter capAlt.

    // --- phase geometry ---
    local departAlt is orbit:semimajoraxis - body:radius.
    local targetAlt is tgtBody:orbit:semimajoraxis - body:radius.
    local vesPos is -body:position.
    local targetPos is tgtBody:position - body:position.
    local orbNml is orbitNormal(vesPos, velocity:orbit).

    local currentPhase is signedAngle(vesPos, targetPos, -orbNml).
    set currentPhase to mod(currentPhase, 360).
    if currentPhase < 0 { set currentPhase to currentPhase + 360. }

    local phaseRate is 360 / orbit:period - 360 / tgtBody:orbit:period.

    // --- initial burn timing (SMA-based) ---
    local r1 is departAlt + body:radius.
    local tof is constant:pi
        * sqrt(((r1 + targetAlt + body:radius) / 2)^3 / body:mu).
    local idealPhase is hohmannPhaseAngle(departAlt, targetAlt, body).
    local deltaPhase is mod(currentPhase - idealPhase, 360).
    if deltaPhase < 0 { set deltaPhase to deltaPhase + 360. }
    local burnEta is deltaPhase / phaseRate.

    // --- correct for target's eccentric orbit ---
    local arrivalTA is TrueAnomalyAtEta(burnEta + tof, tgtBody:orbit).
    set targetAlt to altitudeAtTrueAnomaly(arrivalTA, tgtBody:orbit).
    set idealPhase to hohmannPhaseAngle(departAlt, targetAlt, body).

    print "Ideal phase angle: " + round(idealPhase, 2) + " deg".
    print "Current phase angle: " + round(currentPhase, 2) + " deg".

    set deltaPhase to mod(currentPhase - idealPhase, 360).
    if deltaPhase < 0 { set deltaPhase to deltaPhase + 360. }
    set burnEta to deltaPhase / phaseRate.
    print "Burn ETA: " + round(burnEta, 1) + " s ("
        + round(burnEta / orbit:period, 1) + " orbits)".

    // --- create transfer node ---
    local burnTA is mod(orbit:trueAnomaly + burnEta * 360 / orbit:period, 360).
    if burnTA < 0 { set burnTA to burnTA + 360. }

    local nd is nodeChangeApsis(targetAlt, burnTA, orbit).
    if not nd:istype("Node") {
        print "Failed to create transfer node.".
        return.
    }

    local targetTime is time:seconds + burnEta.
    local orbitsToAdd is round((targetTime - nd:time) / orbit:period).
    if orbitsToAdd > 0 {
        set nd to node(nd:time + orbitsToAdd * orbit:period,
            nd:radialout, nd:normal, nd:prograde).
    }

    local dv is sqrt(nd:prograde^2 + nd:radialout^2 + nd:normal^2).
    print "Transfer to " + tgtBody:name
        + ": dv=" + round(dv, 2) + " m/s"
        + " at T+" + round(nd:time - time:seconds, 1) + "s".
    addNode(nd).

    // --- encounter periapsis tuning ---
    if hasNode {
        tuneEncounter(allNodes[allNodes:length - 1], tgtBody, capAlt).
    }
}

// ============================================================
// Encounter tuning pipeline
// ============================================================

// top-level tuning dispatcher
function tuneEncounter {
    parameter nd.
    parameter tgtBody.
    parameter capAlt.

    if not seekEncounter(nd, tgtBody) {
        print "No encounter with " + tgtBody:name + " found.".
        return.
    }

    local win is measureWindow(nd, tgtBody).

    // phase 1: golden-section minimize to find impact point
    minimizePeriapsis(nd, tgtBody, win[0], win[1]).

    // phase 2: bisect outward from impact to reach target altitude
    if capAlt >= 0 {
        local impactEta is nd:eta.
        local edgeEta is choose win[0]
            if abs(impactEta - win[0]) > abs(impactEta - win[1])
            else win[1].

        // Verify the bracket: need periapsis >= capAlt near the window
        // edge.  For Hohmann (tangent) transfers the encounter window
        // may be too narrow; adding prograde makes the orbit cross the
        // target's, widening it.
        local step is orbit:period / 20.
        local proBoost is 0.
        until proBoost >= 20 {
            local innerEta is choose edgeEta + step
                if edgeEta < impactEta else edgeEta - step.
            set nd:eta to innerEta. wait 0.
            local innerEnc is encOrbit(nd:orbit, tgtBody).
            local innerPeri is choose "none" if innerEnc = "none"
                else innerEnc:periapsis.
            set nd:eta to impactEta. wait 0.
            if innerPeri = "none" or innerPeri >= capAlt { break. }

            set nd:prograde to nd:prograde + 2. wait 0.
            set proBoost to proBoost + 2.
            if not seekEncounter(nd, tgtBody) { break. }
            set win to measureWindow(nd, tgtBody).
            minimizePeriapsis(nd, tgtBody, win[0], win[1]).
            set impactEta to nd:eta.
            set edgeEta to choose win[0]
                if abs(impactEta - win[0]) > abs(impactEta - win[1])
                else win[1].
        }
        if proBoost > 0 {
            print "Added " + round(proBoost, 0)
                + " m/s prograde to widen encounter.".
        }

        seekPeriapsis(nd, tgtBody, capAlt, edgeEta, impactEta).
    }
}

// ------------------------------------------------------------
// Step 1: find any encounter near the Hohmann estimate
// Sweeps nd:eta outward; returns true with nd:eta set, false if none found
// ------------------------------------------------------------
function seekEncounter {
    parameter nd.
    parameter tgtBody.

    if encOrbit(nd:orbit, tgtBody) <> "none" { return true. }

    local eta0 is nd:eta.
    local step is orbit:period / 20.
    local maxDist is orbit:period * 2.
    local dist is step.

    until dist > maxDist {
        if eta0 - dist > 0 {
            set nd:eta to eta0 - dist. wait 0.
            if encOrbit(nd:orbit, tgtBody) <> "none" {
                print "Encounter found at eta offset "
                    + round(-dist, 1) + "s.".
                return true.
            }
        }

        set nd:eta to eta0 + dist. wait 0.
        if encOrbit(nd:orbit, tgtBody) <> "none" {
            print "Encounter found at eta offset +"
                + round(dist, 1) + "s.".
            return true.
        }

        set dist to dist + step.
    }

    set nd:eta to eta0. wait 0.
    return false.
}

// ------------------------------------------------------------
// Step 2: coarse-scan the encounter window boundaries
// Returns list(windowLo, windowHi)
// ------------------------------------------------------------
function measureWindow {
    parameter nd.
    parameter tgtBody.

    local eta0 is nd:eta.
    local step is orbit:period / 20.
    local lo is eta0.
    local hi is eta0.

    local probe is eta0 - step.
    until probe < eta0 - orbit:period * 2 {
        set nd:eta to probe. wait 0.
        if encOrbit(nd:orbit, tgtBody) = "none" { break. }
        set lo to probe.
        set probe to probe - step.
    }
    set lo to lo - step.

    set probe to eta0 + step.
    until probe > eta0 + orbit:period * 2 {
        set nd:eta to probe. wait 0.
        if encOrbit(nd:orbit, tgtBody) = "none" { break. }
        set hi to probe.
        set probe to probe + step.
    }
    set hi to hi + step.

    set nd:eta to eta0. wait 0.
    return list(lo, hi).
}

// ------------------------------------------------------------
// Step 3: golden-section search for minimum encounter periapsis
// Leaves nd:eta at the minimum (impact point)
// ------------------------------------------------------------
function minimizePeriapsis {
    parameter nd.
    parameter tgtBody.
    parameter lo.
    parameter hi.

    local phi is (sqrt(5) - 1) / 2.
    local eta0 is nd:eta.

    local iter is 0.
    until hi - lo < 1 or iter >= 25 {
        local x1 is hi - phi * (hi - lo).
        local x2 is lo + phi * (hi - lo).

        set nd:eta to x1. wait 0.
        local enc1 is encOrbit(nd:orbit, tgtBody).
        local p1 is choose "none" if enc1 = "none"
            else enc1:periapsis.
        set nd:eta to x2. wait 0.
        local enc2 is encOrbit(nd:orbit, tgtBody).
        local p2 is choose "none" if enc2 = "none"
            else enc2:periapsis.

        if p1 = "none"      { set lo to x1. }
        else if p2 = "none" { set hi to x2. }
        else if p1 < p2     { set hi to x2. }
        else                 { set lo to x1. }

        set iter to iter + 1.
    }

    set nd:eta to (lo + hi) / 2. wait 0.
    local finalEnc is encOrbit(nd:orbit, tgtBody).
    local finalPeri is choose "none" if finalEnc = "none"
        else finalEnc:periapsis.
    if finalPeri = "none" {
        set nd:eta to eta0. wait 0.
        print "Impact tuning failed, keeping original node.".
    } else {
        print "Encounter periapsis: " + round(finalPeri, 0)
            + " m (target: impact)".
    }
}

// ------------------------------------------------------------
// Step 4: bisection from window edge to impact point
// Finds the eta where encounter periapsis = tgtPeri
// ------------------------------------------------------------
function seekPeriapsis {
    parameter nd.
    parameter tgtBody.
    parameter tgtPeri.
    parameter edgeEta.
    parameter impactEta.

    local eta0 is nd:eta.

    // verify impact point is below the target altitude
    set nd:eta to impactEta. wait 0.
    local impactEnc is encOrbit(nd:orbit, tgtBody).
    local impactPeri is choose "none" if impactEnc = "none"
        else impactEnc:periapsis.
    if impactPeri = "none" or impactPeri >= tgtPeri {
        set nd:eta to eta0. wait 0.
        print "Target periapsis " + round(tgtPeri, 0)
            + " m not reachable.".
        return.
    }

    local lo is min(edgeEta, impactEta).
    local hi is max(edgeEta, impactEta).
    local impactIsHi is impactEta > edgeEta.

    local bestEta is impactEta.
    local bestErr is abs(impactPeri - tgtPeri).
    local midEnc is 0.
    local midPeri is 0.
    local iter is 0.
    until iter >= 30 {
        local mid is (lo + hi) / 2.
        set nd:eta to mid. wait 0.
        set midEnc to encOrbit(nd:orbit, tgtBody).
        set midPeri to choose "none" if midEnc = "none"
            else midEnc:periapsis.

        if midPeri = "none" or midPeri >= tgtPeri {
            if impactIsHi { set lo to mid. }
            else { set hi to mid. }
        } else {
            if impactIsHi { set hi to mid. }
            else { set lo to mid. }
        }

        if midPeri <> "none" and abs(midPeri - tgtPeri) < bestErr {
            set bestEta to mid.
            set bestErr to abs(midPeri - tgtPeri).
        }

        if midPeri <> "none" and abs(midPeri - tgtPeri) < 1000 { break. }
        if abs(hi - lo) < 0.05 { break. }
        set iter to iter + 1.
    }

    set nd:eta to bestEta. wait 0.
    set midEnc to encOrbit(nd:orbit, tgtBody).
    set midPeri to choose "none" if midEnc = "none"
        else midEnc:periapsis.
    if midPeri = "none" or abs(midPeri - tgtPeri) > max(5000, tgtPeri * 0.1) {
        // revert to impact point if target unreachable or error > 10%
        set nd:eta to impactEta. wait 0.
        if midPeri = "none" {
            print "Periapsis tuning failed, keeping impact trajectory.".
        } else {
            print "Target periapsis " + round(tgtPeri, 0)
                + " m not reachable (max: " + round(midPeri, 0) + " m),"
                + " keeping impact trajectory.".
        }
    } else {
        print "Encounter periapsis: " + round(midPeri, 0)
            + " m (target: " + round(tgtPeri, 0) + " m"
            + ", err: " + round(midPeri - tgtPeri, 0) + " m)".
    }
}

