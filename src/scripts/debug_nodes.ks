// debug_nodes.ks prints info about all maneuver nodes and the current orbit
@lazyGlobal off.

print "--- Current Orbit ---".
print "  body=" + orbit:body:name.
print "  apo=" + orbit:apoapsis + " peri=" + orbit:periapsis.
print "  ecc=" + orbit:eccentricity + " sma=" + orbit:semimajoraxis.
print "  period=" + orbit:period.

if not hasNode {
    print "No maneuver nodes.".
} else {
    local i is 0.
    for nd in allNodes {
        print "--- Node " + i + " ---".
        print "  eta=" + nd:eta + "s".
        print "  pro=" + nd:prograde + " rad=" + nd:radialout + " nrm=" + nd:normal.
        print "  dv=" + nd:deltav:mag + " m/s".
        print "  post-orbit apo=" + nd:orbit:apoapsis + " peri=" + nd:orbit:periapsis.
        print "  post-orbit ecc=" + nd:orbit:eccentricity.
        set i to i + 1.
    }
    print "--- Final Orbit ---".
    local lastOrb is allNodes[allNodes:length-1]:orbit.
    print "  apo=" + lastOrb:apoapsis + " peri=" + lastOrb:periapsis.
}
