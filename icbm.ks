// script parameters
declare parameter targetName is "Valentina's Gift".
declare parameter turnRate is 10.
declare parameter targetThres is 500.

// display only icbm information
clearScreen.
print "RUNNING icbm".

// only run if trajectories is available
if addons:tr:available {
    // define utility functions
    runoncepath("lib/terminal").
    runoncepath("lib/engine").
    runoncepath("lib/geo_nav").

    // set target coordinates
    local targetWaypoint is waypoint(targetName).

    // create steering controller
    local heading_pid is pidLoop(2.0, 0.5, 0.2).
    local heading_error is 0.
    set yaw to geo_heading(ship:geoposition, targetWaypoint:geoposition).
    set pitch to 90.
    lock steering to heading(yaw, pitch).

    // throttle up
    stage.
    local targetTWR is 1.7.
    lock gravAcc to body:mu/((body:radius + altitude)*(body:radius + altitude)).
    lock weight to gravAcc * mass.
    lock impact_error to geo_arclength(ship:geoposition, targetWaypoint:geoposition, ship:body:radius).
    lock throttle to min(impact_error/10000, throttleForThrust(targetTWR * weight)).

    local dist_error is geo_arclength(ship:geoposition, targetWaypoint:geoposition, ship:body:radius)+1000.
    local prev_dist_error is dist_error.
    until addons:tr:hasImpact and geo_arclength(addons:tr:impactPos, targetWaypoint:geoposition, ship:body:radius) < targetThres {
        set pitch to max(90 - ship:velocity:surface:mag/turnRate, 20).
        if addons:tr:hasImpact {
            // exit early if distance starts increasing.
            set prev_dist_error to dist_error.
            set dist_error to geo_arclength(addons:tr:impactPos, targetWaypoint:geoposition, ship:body:radius).
            if dist_error < targetThres*100 and ship:velocity:surface:mag > 100 and dist_error > prev_dist_error {
                print "OOPS! :)".
                break.
            }

            // run KP-loop to minimize heading error
            set heading_error to geo_angle(ship:geoposition, addons:tr:impactPos, targetWaypoint:geoposition).
            // if heading_error > 180 {set heading_error to heading_error-360.}
            // if heading_error < -180 {set heading_error to heading_error+360.}
            if abs(heading_error) < 10 {
                set yaw to geo_heading(ship:geoposition, targetWaypoint:geoposition) + heading_pid:update(time:seconds, heading_error).
            }

            print "Impact Geo-Distance Error: " + dist_error at(0,19).
            print "Impact-Target Angle: " + heading_error at(0,20).
        }
        print "Target Heading: " + targetWaypoint:geoposition:heading at(0,15).
        print "Target Geo-Heading: " + geo_heading(ship:geoposition, targetWaypoint:geoposition) at(0,16).
        print "Target Distance: " + targetWaypoint:geoposition:distance at(0,17).
        print "Target Geo-Distance: " + geo_arclength(ship:geoposition, targetWaypoint:geoposition, ship:body:radius) at(0,18).
    }

    lock throttle to 0.
    lock steering to srfPrograde.
    // set pid to pidLoop(0.01, 0, 0.006).
    until ship:altitude < 0 {
        set dist_error to geo_arclength(addons:tr:impactPos, targetWaypoint:geoposition, ship:body:radius).
        set heading_error to geo_angle(ship:geoposition, addons:tr:impactPos, targetWaypoint:geoposition).

        // set yaw to srfPrograde:yaw.
        // set pitch to max(srfPrograde:pitch, srfPrograde:pitch - pid:update(time:seconds, dist_error)).

        print "Target Heading: " + targetWaypoint:geoposition:heading at(0,15).
        print "Target Geo-Heading: " + geo_heading(ship:geoposition, targetWaypoint:geoposition) at(0,16).
        print "Target Distance: " + targetWaypoint:geoposition:distance at(0,17).
        print "Target Geo-Distance: " + geo_arclength(ship:geoposition, targetWaypoint:geoposition, ship:body:radius) at(0,18).
        print "Impact Geo-Distance Error: " + dist_error at(0,19).
        print "Impact-Target Angle: " + heading_error at(0,20).
    }

} else {
    print("Script requires the Trajectories mod to work").
}