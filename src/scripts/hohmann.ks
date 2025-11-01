// DEPRICATED/OLD CODE, use transfer.ks instead
// hohmann.ks creates the maneuver nodes to execute a Hohmann transfer at the current orbit
@lazyGlobal off.

declare parameter apo is -1. // change current apoapsis to
declare parameter peri is -1. // change current periapsis to
declare parameter patchNum is 0.
declare parameter safety is true.

// define utility functions
runoncepath("0:/src/core/node").

local targetPatch is orbit.
from {local i is 0.} until i = patchNum step {set i to i+1.} do {
    if targetPatch:hasnextpatch {
        set targetPatch to targetPatch:nextpatch.
    }
}

if apo = -1 {
    set apo to targetPatch:apoapsis.
    print "set apo to " + targetPatch:apoapsis.
}

if peri = -1 {
    set peri to apo.
    print "set peri to " + apo.
}

// create a node to change apoapsis
local node1 is nodeChangeApoapsis(apo, targetPatch, safety).
local node1Alt is targetPatch:periapsis.
if safety and targetPatch:periapsis < targetPatch:body:atm:height {
    set node1 to nodeChangePeriapsis(apo, targetPatch, safety).
    set node1Alt to targetPatch:apoapsis.
}

// create a node to change periapsis
local node2 is nodeChangePeriapsis(peri, targetPatch, safety).
if node1:isType("Node") {
    add node1.
    if node1:deltav:sqrmagnitude < 0.01 {
        remove node1.
        print "node1 has low dv, removing".
    } else {
        print "added node with dv of " + node1:deltav:mag.
        if abs(node1:orbit:periapsis - node1Alt) < abs(node1:orbit:apoapsis - node1Alt) {
            set node2 to nodeChangePeriapsis(peri, node1:orbit, safety).
        } else {
            set node2 to nodeChangeApoapsis(peri, node1:orbit, safety).
        }
    }
    
    if node2:isType("Node") {
        add node2.
        if node2:deltav:sqrmagnitude < 0.01 {remove node2. print "node2 has low dv, removing".}
        else { print "added node with dv of " + node2:deltav:mag. }
    }
}