//transfer
// this script creates the maneuver nodes to execute a Hohmann transfer at the current orbit

declare parameter apo.
declare parameter peri is -1.
declare parameter targetPatch is orbit.
declare parameter execute is false.

// define utility functions
runoncepath("utils/nodeUtils.ks").

if  peri = -1 {
    set peri to targetPatch:periapsis.
    print "set peri to " + targetPatch:periapsis.
}

// create a node to change apoapsis
local node1 is nodeChangeApoapsis(apo, targetPatch).
if not node1:isType("Node") {
    set node1 to nodeChangePeriapsis(apo, targetPatch).
}

// create a node to change periapsis
if node1:isType("Node") {
    add node1.
    if node1:deltav:sqrmagnitude < 0.01 {
        remove node1.
    } else {
        print "added node with dv of " + node1:deltav:mag.
        local node2 is nodeChangePeriapsis(peri, node1:orbit).
        if node2:isType("Node") {
            add node2.
            if node2:deltav:sqrmagnitude < 0.01 {remove node2.}
            else { print "added node with dv of " + node2:deltav:mag. }
        }
    }
}

// execute nodes if true.
if execute {
    run maneuver.
    run maneuver.
}