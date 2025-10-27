// this script plans nodes to change the true anomaly angle between the current and target craft
// currently the script assumes the current and target craft are already on similar circular orbits
// this script can be used to plan a rendevous, or maintain a separation between the crafts

parameter targetAngle is 0.

print "Ownship Orbital Period: " + ship:orbit:period.

// print "Ownship True Anomaly: " + ship:orbit:trueanomaly.

print "Ownship Epoch: " + ship:orbit:epoch.
print "Ownship Mean Anomoly at Epoch: " + ship:orbit:meananomalyatepoch.
//lock shipMeanAnomoly to ship:orbit:meananomalyatepoch + 360*(ship:orbit:eta:periapsis + time:seconds - ship:orbit:epoch)/ship:orbit:period.
print "Ownship Mean Anomoly at Periapsis: " + 0. //shipMeanAnomoly.

print "Target Argument of Periapsis: " + ship:orbit:argumentofperiapsis.
print "Ownship Longitude of Ascending Node: " + ship:orbit:longitudeofascendingnode.
lock shipCombinedAngle to ship:orbit:argumentofperiapsis + ship:orbit:longitudeofascendingnode.
print "Ownship Combined Angle: " + shipCombinedAngle.

if hasTarget {
    print "Target Orbital Period: " + target:orbit:period.

    // print "Target True Anomaly: " + target:orbit:trueanomaly.

    print "Target Epoch: " + target:orbit:epoch.
    print "Target Mean Anomoly at Epoch: " + target:orbit:meananomalyatepoch.
    local lock targetMeanAnomoly to target:orbit:meananomalyatepoch + 360*(ship:orbit:eta:periapsis + time:seconds - target:orbit:epoch)/target:orbit:period.
    print "Target Mean Anomoly At Ownship Periapsis: " + targetMeanAnomoly.

    print "Target Argument of Periapsis: " + target:orbit:argumentofperiapsis.
    print "Target Longitude of Ascending Node: " + target:orbit:longitudeofascendingnode.
    local lock targetCombinedAngle to targetMeanAnomoly + target:orbit:argumentofperiapsis + target:orbit:longitudeofascendingnode.
    print "Target Combined Angle: " + targetCombinedAngle.

    local lock currAngle to mod(180 + targetCombinedAngle - shipCombinedAngle, 360) - 180.
    print "Delta Angle at Ownship Periapsis: " + currAngle.
    print "Requested Delta Mean Anomoly: " + targetAngle.
    local lock angleError to (mod(180 + targetAngle-currAngle, 360) - 180).
    
    run shift_by_anomaly(angleError, target:orbit:apoapsis, target:orbit:periapsis).
}