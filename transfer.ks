//transfer
// this script creates the maneuver nodes to execute a Hohmann transfer at the current orbit

declare parameter apo.
declare parameter peri is -1.
declare parameter execute is false.
declare parameter targetPatch is orbit.

// define utility functions
runoncepath("utils/nodeUtils.ks").

if peri = -1 {
    set peri to targetPatch:periapsis.
    print "set peri to " + targetPatch:periapsis.
}

// create a node to change apoapsis
if targetPatch:periapsis < 0 or targetPatch:periapsis < targetPatch:body:atm:height {
    set node1 to nodeChangePeriapsis(apo, targetPatch).
    set node1Alt to targetPatch:apoapsis.
} else {
    set node1 to nodeChangeApoapsis(apo, targetPatch).
    set node1Alt to targetPatch:periapsis.
}


// create a node to change periapsis
if node1:isType("Node") {
    add node1.
    if node1:deltav:sqrmagnitude < 0.01 {
        remove node1.
        print "node1 has low dv, removing".
    } else {
        print "added node with dv of " + node1:deltav:mag.
        if abs(node1:orbit:periapsis - node1Alt) < abs(node1:orbit:apoapsis - node1Alt) {
            set node2 to nodeChangePeriapsis(peri, node1:orbit).
        } else {
            set node2 to nodeChangeApoapsis(peri, node1:orbit).
        }
        if node2:isType("Node") {
            add node2.
            if node2:deltav:sqrmagnitude < 0.01 {remove node2. print "node2 has low dv, removing".}
            else { print "added node with dv of " + node2:deltav:mag. }
        }
    }
}

// execute nodes if true.
if execute {
    run maneuver.
    remove nextNode.
    run maneuver.
}