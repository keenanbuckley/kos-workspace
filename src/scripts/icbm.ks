// icbm.ks attempts to fly and crash into a target waypoint
@lazyGlobal off.

// script parameters
parameter targetName is "Valentina's Gift".
parameter turnRate is 10.
parameter targetThres is 500.

// display only icbm information
clearScreen.
print "RUNNING icbm".

// only run if trajectories is available
if addons:tr:available {
    // define utility functions
    runOncePath("0:/src/display/terminal").
    runOncePath("0:/src/core/engine").
    runOncePath("0:/src/core/geo_nav").

    // set target coordinates
    local targetWaypoint is waypoint(targetName).

    // create steering controller
    local headingPid is pidLoop(2.0, 0.5, 0.2).
    local headingError is 0.
    set yaw to geoHeading(ship:geoposition, targetWaypoint:geoposition).
    set pitch to 90.
    lock steering to heading(yaw, pitch).

    // throttle up
    stage.
    local targetTWR is 1.7.
    lock gravAcc to body:mu/((body:radius + altitude)*(body:radius + altitude)).
    lock weight to gravAcc * mass.
    lock impactError to geoArclength(ship:geoposition, targetWaypoint:geoposition, ship:body:radius).
    lock throttle to min(impactError/10000, throttleForThrust(targetTWR * weight)).

    local distError is geoArclength(ship:geoposition, targetWaypoint:geoposition, ship:body:radius)+1000.
    local prevDistError is distError.
    until addons:tr:hasImpact and geoArclength(addons:tr:impactPos, targetWaypoint:geoposition, ship:body:radius) < targetThres {
        set pitch to max(90 - ship:velocity:surface:mag/turnRate, 20).
        if addons:tr:hasImpact {
            // exit early if distance starts increasing.
            set prevDistError to distError.
            set distError to geoArclength(addons:tr:impactPos, targetWaypoint:geoposition, ship:body:radius).
            if distError < targetThres*100 and ship:velocity:surface:mag > 100 and distError > prevDistError {
                print "OOPS! :)".
                break.
            }

            // run KP-loop to minimize heading error
            set headingError to geoAngle(ship:geoposition, addons:tr:impactPos, targetWaypoint:geoposition).
            // if headingError > 180 {set headingError to headingError-360.}
            // if headingError < -180 {set headingError to headingError+360.}
            if abs(headingError) < 10 {
                set yaw to geoHeading(ship:geoposition, targetWaypoint:geoposition) + headingPid:update(time:seconds, headingError).
            }

            print "Impact Geo-Distance Error: " + distError at(0,19).
            print "Impact-Target Angle: " + headingError at(0,20).
        }
        print "Target Heading: " + targetWaypoint:geoposition:heading at(0,15).
        print "Target Geo-Heading: " + geoHeading(ship:geoposition, targetWaypoint:geoposition) at(0,16).
        print "Target Distance: " + targetWaypoint:geoposition:distance at(0,17).
        print "Target Geo-Distance: " + geoArclength(ship:geoposition, targetWaypoint:geoposition, ship:body:radius) at(0,18).
    }

    lock throttle to 0.
    lock steering to srfPrograde.
    // set pid to pidLoop(0.01, 0, 0.006).
    until ship:altitude < 0 {
        set distError to geoArclength(addons:tr:impactPos, targetWaypoint:geoposition, ship:body:radius).
        set headingError to geoAngle(ship:geoposition, addons:tr:impactPos, targetWaypoint:geoposition).

        // set yaw to srfPrograde:yaw.
        // set pitch to max(srfPrograde:pitch, srfPrograde:pitch - pid:update(time:seconds, distError)).

        print "Target Heading: " + targetWaypoint:geoposition:heading at(0,15).
        print "Target Geo-Heading: " + geoHeading(ship:geoposition, targetWaypoint:geoposition) at(0,16).
        print "Target Distance: " + targetWaypoint:geoposition:distance at(0,17).
        print "Target Geo-Distance: " + geoArclength(ship:geoposition, targetWaypoint:geoposition, ship:body:radius) at(0,18).
        print "Impact Geo-Distance Error: " + distError at(0,19).
        print "Impact-Target Angle: " + headingError at(0,20).
    }

} else {
    print "Script requires the Trajectories mod to work".
}
