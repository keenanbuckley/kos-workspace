// midcourse.ks — mid-course correction for encounter inclination and periapsis
//   Requires a departure node with an encounter (run transfer_to first).
//   Adds a radial+normal correction node at the transfer midpoint
//   and a capture node at encounter periapsis.
@lazyGlobal off.

parameter targetBody.
parameter targetInc.
parameter captureAlt is -1.

runOncePath("0:/src/core/node").

if targetBody:istype("String") {
    set targetBody to body(targetBody).
}

midcourse(targetBody, targetInc, captureAlt).

function midcourse {
    parameter tgtBody.
    parameter tgtInc.
    parameter capAlt.

    // --- validate departure node ---
    if not hasNode {
        print "Error: no departure node found.".
        return.
    }
    local departNode is allNodes[0].
    local enc is encOrbit(departNode:orbit, tgtBody).
    if enc = "none" {
        print "Error: departure node does not encounter "
            + tgtBody:name + ".".
        return.
    }

    // --- baseline encounter ---
    local baseInc is enc:inclination.
    local basePeri is enc:periapsis.
    print "Baseline encounter: inc="
        + round(baseInc, 2) + " deg, peri="
        + round(basePeri, 0) + " m".

    if capAlt = -1 {
        set capAlt to max(10000, basePeri).
    }

    // --- burn placement at transfer midpoint ---
    local encTime is findEncounterTime(departNode:orbit, tgtBody).
    if encTime < 0 {
        print "Error: could not determine encounter time.".
        return.
    }
    local burnTime is departNode:time
        + 0.5 * (encTime - departNode:time).

    // --- create trial node ---
    local nd is node(burnTime, 0, 0, 0).
    add nd.
    wait 0.

    // --- Newton iteration ---
    local maxIter is 15.
    local h is 1.0.
    local maxStep is 50.
    local bestRad is 0.
    local bestNrm is 0.
    local bestErr is 1e12.
    local converged is false.
    local iter is 0.

    until iter >= maxIter {
        // base evaluation
        local enc0 is encOrbit(nd:orbit, tgtBody).
        if enc0 = "none" {
            print "Encounter lost at iteration " + iter + ".".
            set nd:radialout to bestRad.
            set nd:normal to bestNrm.
            wait 0.
            break.
        }
        local inc0 is enc0:inclination.
        local peri0 is enc0:periapsis.

        local errInc is inc0 - tgtInc.
        local errPeri is peri0 - capAlt.
        local errMag is sqrt(errInc^2 + (errPeri / 1000)^2).

        print "  iter " + iter
            + ": inc err=" + round(errInc, 2) + " deg"
            + ", peri err=" + round(errPeri, 0) + " m".

        if errMag < bestErr {
            set bestErr to errMag.
            set bestRad to nd:radialout.
            set bestNrm to nd:normal.
        }

        if abs(errInc) < 0.5 and abs(errPeri) < 1000 {
            set converged to true.
            break.
        }

        // compute Jacobian via finite differences
        local rad0 is nd:radialout.
        local nrm0 is nd:normal.

        set nd:radialout to rad0 + h. wait 0.
        local encR is encOrbit(nd:orbit, tgtBody).
        if encR = "none" {
            set nd:radialout to rad0. wait 0.
            print "Encounter lost during radial perturbation.".
            break.
        }
        local dIncDr is (encR:inclination - inc0) / h.
        local dPeriDr is (encR:periapsis - peri0) / h.

        set nd:radialout to rad0.
        set nd:normal to nrm0 + h. wait 0.
        local encN is encOrbit(nd:orbit, tgtBody).
        if encN = "none" {
            set nd:normal to nrm0. wait 0.
            print "Encounter lost during normal perturbation.".
            break.
        }
        local dIncDn is (encN:inclination - inc0) / h.
        local dPeriDn is (encN:periapsis - peri0) / h.

        // restore base state
        set nd:normal to nrm0. wait 0.

        // invert 2x2 Jacobian
        local det is dIncDr * dPeriDn - dIncDn * dPeriDr.
        if abs(det) < 1e-12 {
            print "Singular Jacobian, aborting.".
            break.
        }

        local dRad is -(dPeriDn * errInc - dIncDn * errPeri) / det.
        local dNrm is -(-dPeriDr * errInc + dIncDr * errPeri) / det.

        // step-size limiting
        local stepMag is sqrt(dRad^2 + dNrm^2).
        if stepMag > maxStep {
            set dRad to dRad * maxStep / stepMag.
            set dNrm to dNrm * maxStep / stepMag.
        }

        // apply step with encounter-loss recovery
        local prevRad is rad0.
        local prevNrm is nrm0.
        set nd:radialout to rad0 + dRad.
        set nd:normal to nrm0 + dNrm.
        wait 0.

        local halvings is 0.
        until halvings >= 3 {
            if encOrbit(nd:orbit, tgtBody) <> "none" { break. }
            set dRad to dRad / 2.
            set dNrm to dNrm / 2.
            set nd:radialout to prevRad + dRad.
            set nd:normal to prevNrm + dNrm.
            wait 0.
            set halvings to halvings + 1.
        }
        if halvings >= 3 and encOrbit(nd:orbit, tgtBody) = "none" {
            print "Cannot recover encounter, reverting to best.".
            set nd:radialout to bestRad.
            set nd:normal to bestNrm.
            wait 0.
            break.
        }

        set iter to iter + 1.
    }

    if not converged {
        set nd:radialout to bestRad.
        set nd:normal to bestNrm.
        wait 0.
        local bestEnc is encOrbit(nd:orbit, tgtBody).
        if bestEnc <> "none" {
            print "WARNING: did not converge. Best: inc="
                + round(bestEnc:inclination, 2) + " deg, peri="
                + round(bestEnc:periapsis, 0) + " m".
        } else {
            print "ERROR: no encounter at best solution.".
            remove nd.
            return.
        }
    }

    // --- mid-course summary ---
    local mcDv is sqrt(nd:radialout^2 + nd:normal^2 + nd:prograde^2).
    print "Mid-course correction: dv=" + round(mcDv, 2) + " m/s".

    // --- capture node at encounter periapsis ---
    local finalEnc is encOrbit(nd:orbit, tgtBody).
    local capNode is nodeChangeApsis(capAlt, 0, finalEnc).
    addNode(capNode).

    if capNode:istype("Node") {
        local capDv is sqrt(capNode:radialout^2 + capNode:normal^2
            + capNode:prograde^2).
        print "Capture burn: dv=" + round(capDv, 2) + " m/s".
        print "Total dv: " + round(mcDv + capDv, 2) + " m/s".
    }
}

// find the time at which the trajectory enters the target body's SOI
function findEncounterTime {
    parameter startOrbit.
    parameter tgtBody.

    local patch is startOrbit.
    until not patch:hasnextpatch {
        if patch:nextpatch:body = tgtBody {
            return time:seconds + patch:nextpatcheta.
        }
        set patch to patch:nextpatch.
    }
    return -1.
}
