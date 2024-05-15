//transfer
// this script creates the maneuver nodes to execute a Hohmann transfer at the current orbit

declare parameter apo.
declare parameter peri is periapsis.
declare parameter execute is false.

// define utility functions
runoncepath("utils/miscUtils.ks").
runoncepath("utils/nodeUtils.ks").

// create a node to change apoapsis
local node1 is nodeChangeApoapsis(apo, orbit).
if not node1:isType("Node") {
    set node1 to nodeChangePeriapsis(apo, orbit).
}

// create a node to change periapsis
if node1:isType("Node") {
    add node1.
    local node2 is nodeChangePeriapsis(peri, node1:orbit).
    if abs(peri - periapsis) > 10 and node2:isType("Node") {
        add node2.
    }
}

// execute nodes if true.
if execute {
    run maneuver.
    run maneuver.
}