// hop.ks launches toward a waypoint on a suborbital trajectory and lands with parachutes
@lazyGlobal off.

parameter targetName is "Target".
parameter turnRate is 10.
parameter targetThreshold is 1000.
parameter targetTWR is 1.7.
parameter initialSpeed is 100.

clearScreen.
print "RUNNING hop".

if not addons:tr:available {
    print "ERROR: Trajectories mod required.".
}

if addons:tr:available {
    runOncePath("0:/src/display/terminal").
    runOncePath("0:/src/core/engine").
    runOncePath("0:/src/core/geo_nav").

    local targetWaypoint is waypoint(targetName).
    local targetGeo is targetWaypoint:geoposition.
    addons:tr:settarget(targetGeo).

    // shared state
    lock gravAcc to body:mu / ((body:radius + altitude)^2).
    lock weight to gravAcc * mass.
    local distError is geoArclength(ship:geoposition, targetGeo, ship:body:radius).

    // === PHASE 1: ASCENT ===
    print "PHASE 1: ASCENT" at(0,2).

    // steering
    local yaw is geoHeading(ship:geoposition, targetGeo).
    local pitch is 90.

    // launch
    stage.

    // throttle
    local thrustScale is geoArclength(ship:geoposition, targetGeo, ship:body:radius).
    lock throttle to min(thrustScale / 10000, throttleForThrust(targetTWR * weight)).

    // SAS stability during initial climb
    sas on.
    set sasMode to "stability".

    when ship:velocity:surface:mag > initialSpeed then {
        sas off.
        lock steering to heading(yaw, pitch).
    }

    // divergence tracking
    local minDistError is distError.

    // ascent loop: burn until impact converges on target
    local impactConverged is false.
    until impactConverged {
        // in-loop staging: stage once if no thrust, then reset divergence tracking
        if maxThrust = 0 or engineFlameout() {
            print "Staging.              " at(0,3).
            stage.
            wait until stage:ready.
            wait 0.
            set minDistError to distError + targetThreshold * 10.
        }

        if ship:velocity:surface:mag >= initialSpeed {
            set pitch to max(90 - (ship:velocity:surface:mag - initialSpeed) / turnRate, 20).
        }

        if addons:tr:hasImpact {
            local impactGeo is addons:tr:impactPos.
            set distError to geoArclength(impactGeo, targetGeo, ship:body:radius).
            set minDistError to min(minDistError, distError).
            set thrustScale to distError.

            if distError < targetThreshold {
                set impactConverged to true.
            } else if ship:velocity:surface:mag > 100
                    and distError > minDistError + targetThreshold {
                print "Impact diverging, cutting engines." at(0,4).
                break.
            }

            set yaw to geoHeading(ship:geoposition, targetGeo).

            print "Impact Error:   " + round(distError) + " m       " at(0,11).
        }

        print "Phase:    ASCENT                " at(0,6).
        print "Altitude: " + round(altitude) + " m       " at(0,7).
        print "Speed:    " + round(ship:velocity:surface:mag) + " m/s     " at(0,8).
        print "Pitch:    " + round(pitch, 1) + " deg      " at(0,9).
        print "Heading:  " + round(yaw, 1) + " deg      " at(0,10).
    }

    // engine cutoff
    lock throttle to 0.
    print "Engine cutoff.                      " at(0,4).

    // === PHASE 2: COAST (stage 1 correction) ===
    print "PHASE 2: COAST" at(0,2).

    lock steering to srfPrograde.
    local correctionBurning is false.

    // coast with stage 1 until apoapsis, correcting if needed
    until ship:verticalspeed < 0 {
        if addons:tr:hasImpact {
            local impactGeo is addons:tr:impactPos.
            set distError to geoArclength(impactGeo, targetGeo, ship:body:radius).

            if distError > targetThreshold and altitude > body:atm:height {
                lock steering to heading(geoHeading(impactGeo, targetGeo), 0).
                lock throttle to throttleForThrust(targetTWR * weight).
                set correctionBurning to true.
            } else if correctionBurning {
                lock steering to srfPrograde.
                lock throttle to 0.
                set correctionBurning to false.
            }

            print "Impact Error:   " + round(distError) + " m       " at(0,11).
        }

        print "Phase:    COAST (stage 1 corr.) " at(0,6).
        print "Altitude: " + round(altitude) + " m       " at(0,7).
        print "Speed:    " + round(ship:velocity:surface:mag) + " m/s     " at(0,8).
        clearLine(9).
        clearLine(10).
        if correctionBurning {
            print "CORRECTING TRAJECTORY" at(0,13).
        } else {
            clearLine(13).
        }
    }

    // cut engines before separation
    lock throttle to 0.
    lock steering to srfPrograde.
    wait 0.

    // separate stage 1
    stage.
    print "Stage 1 separated.                  " at(0,4).
    clearLine(13).

    // === PHASE 3: COAST (stage 2 correction) ===
    print "PHASE 3: COAST" at(0,2).

    // wait a tick for Trajectories to recalculate after separation
    wait 0.
    set correctionBurning to false.

    // correct with stage 2 side-mounted engines
    until altitude < body:atm:height * 0.15 and ship:verticalspeed < 0 {
        if addons:tr:hasImpact {
            local impactGeo is addons:tr:impactPos.
            set distError to geoArclength(impactGeo, targetGeo, ship:body:radius).

            // correction with side-mounted engines
            if distError > targetThreshold and altitude > body:atm:height {
                lock steering to heading(geoHeading(impactGeo, targetGeo), 0).
                lock throttle to 1.
                set correctionBurning to true.
            } else if correctionBurning {
                lock throttle to 0.
                set correctionBurning to false.
            }

            // flip to retrograde for heat shield re-entry
            if not correctionBurning {
                if altitude < body:atm:height and ship:verticalspeed < 0 {
                    lock steering to srfRetrograde.
                } else {
                    lock steering to srfPrograde.
                }
            }

            print "Impact Error:   " + round(distError) + " m       " at(0,11).
        }

        print "Phase:    COAST (stage 2 corr.) " at(0,6).
        print "Altitude: " + round(altitude) + " m       " at(0,7).
        print "Speed:    " + round(ship:velocity:surface:mag) + " m/s     " at(0,8).
        clearLine(9).
        clearLine(10).
        if correctionBurning {
            print "CORRECTING TRAJECTORY" at(0,13).
        } else {
            clearLine(13).
        }
    }

    lock throttle to 0.
    clearLine(13).

    // === PHASE 4: DESCENT ===
    print "PHASE 4: DESCENT" at(0,2).
    clearLine(4).

    unlock steering.
    unlock throttle.
    sas on.

    // arm all parachutes
    for pt in ship:parts {
        if pt:hasModule("ModuleParachute") {
            local chuteMod is pt:getModule("ModuleParachute").
            if chuteMod:hasEvent("deploy chute") {
                chuteMod:doEvent("deploy chute").
            }
        }
    }
    print "Parachutes armed.                   " at(0,4).

    local gearDeployed is false.
    until ship:status = "LANDED" or ship:status = "SPLASHED" {
        if addons:tr:hasImpact {
            local impactGeo is addons:tr:impactPos.
            set distError to geoArclength(impactGeo, targetGeo, ship:body:radius).
            print "Impact Error:   " + round(distError) + " m       " at(0,11).
        }

        // deploy gear and switch to SAS retrograde once slow enough
        if not gearDeployed and ship:velocity:surface:mag < 50 {
            gear on.
            sas on.
            set sasMode to "retrograde".
            set gearDeployed to true.
            print "Gear deployed.                      " at(0,3).
        }

        print "Phase:    DESCENT               " at(0,6).
        print "Altitude: " + round(altitude) + " m       " at(0,7).
        print "Speed:    " + round(ship:velocity:surface:mag) + " m/s     " at(0,8).
        print "V-Speed:  " + round(ship:verticalspeed, 1) + " m/s     " at(0,9).
        clearLine(10).
    }

    // landed
    set ship:control:pilotMainThrottle to 0.
    local finalDist is geoArclength(ship:geoposition, targetGeo, ship:body:radius).
    clearLine(4).
    clearLine(11).
    print "LANDED. Status: " + ship:status at(0,4).
    print "Distance to target: " + round(finalDist) + " m" at(0,14).
}
