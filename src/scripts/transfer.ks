// transfer.ks creates the maneuver nodes to execute a Bi-elliptic transfer at the target patch
@lazyGlobal off.

parameter apo is -1.            // final apoapsis (defaults to apoapsis of target patch)
parameter peri is -1.           // final periapsis (defaults to target apoapsis)
parameter rb is -1.             // common apsis for bi-elliptic transfer (default is a hohmann transfer)
parameter burn_anomoly is 0.    // angle from periapsis from which to start burn (only implemented for 0 and 180 so far)
parameter patchNum is 0.        // How many orbital patches from now to execute maneuver
parameter safety is true.       // Ensure orbits do not go above the body's SOI or below it's atmosphere

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
    print "set final apoapsis to " + targetPatch:apoapsis.
}

if peri = -1 {
    set peri to apo.
    print "set final periapsis to " + apo.
}

if rb = -1 {
    set rb to apo.
    print "common apo = final apo, conducting hohmann transfer".
}

if safety and targetPatch:periapsis < 0 {
    print "burn anomoly is below orbiting body's surface; setting to burn at apoapsis".
    set burn_anomoly to 180.
} else if safety and targetPatch:periapsis < targetPatch:body:atm:height and targetPatch:apoapsis > targetPatch:body:atm:height {
    print "burn anomoly is below orbiting body's atmosphere; setting to burn at apoapsis".
    set burn_anomoly to 180.
}

// create first node for transfer (burn to common apsis)
local node1 is node(0, 0, 0, 0).
local node1Alt is 0.
if hasNode { // if future nodes already exist, start planning from last node's orbit
    if burn_anomoly = 0 { // adjust common apsis from periapsis
        set node1 to nodeChangeApoapsis(rb, allNodes[allNodes:length-1]:orbit, safety).
        set node1Alt to allNodes[allNodes:length-1]:orbit:periapsis.
    } else if burn_anomoly = 180 { // adjust common apsis from apoapsis
        set node1 to nodeChangePeriapsis(rb, allNodes[allNodes:length-1]:orbit, safety).
        set node1Alt to allNodes[allNodes:length-1]:orbit:apoapsis.
    }
    // else { // adjust common apsis from target true anomoly
    //     set node1 to nodeChangeApsis(rb, constant:degtorad * burn_anomoly, allNodes[allNodes:length-1]:orbit, safety).
    //     set node1Alt to allNodes[allNodes:length-1]:orbit:semimajoraxis * (1 - allNodes[allNodes:length-1]:orbit:eccentricity^2) / (1 + allNodes[allNodes:length-1]:orbit:eccentricity*cos(constant:degtorad * burn_anomoly)).
    // }
} else { // if no nodes exist
    if burn_anomoly = 0 { // adjust common apsis from periapsis
        set node1 to nodeChangeApoapsis(rb, targetPatch, safety).
        set node1Alt to targetPatch:semimajoraxis * (1 - targetPatch:eccentricity^2) / (1 + targetPatch:eccentricity).
    } else if burn_anomoly = 180 { // adjust common apsis from apoapsis
        set node1 to nodeChangePeriapsis(rb, targetPatch, safety).
        set node1Alt to targetPatch:semimajoraxis * (1 - targetPatch:eccentricity^2) / (1 - targetPatch:eccentricity).
    } else { // adjust common apsis from target true anomoly
        set node1 to nodeChangeApsis(rb, burn_anomoly, targetPatch, safety).
        set node1Alt to targetPatch:semimajoraxis * (1 - targetPatch:eccentricity^2) / (1 + targetPatch:eccentricity*cos(burn_anomoly)).
        print(node1Alt).
    }
}

// add node if dv is high enough
print "Adding first node...".
addNode(node1).

// create second node for transfer (burn to target periapsis)
local node2 is node(0, 0, 0, 0). // default if no nodes exist
if hasNode {
    if abs(allNodes[allNodes:length-1]:orbit:periapsis - node1Alt) < abs(allNodes[allNodes:length-1]:orbit:apoapsis - node1Alt) {
        set node2 to nodeChangePeriapsis(peri, allNodes[allNodes:length-1]:orbit, safety).
    } else {
        set node2 to nodeChangeApoapsis(peri, allNodes[allNodes:length-1]:orbit, safety).
    }
}

// add node if dv is high enough
print "Adding second node...".
addNode(node2).

// create third node for transfer (burn to target apoapsis)
local node3 is node(0, 0, 0, 0). // default if no nodes exist
if hasNode {
    if rb > apo {
        set node3 to nodeChangeApoapsis(apo, allNodes[allNodes:length-1]:orbit, safety).
    } else {
        set node3 to nodeChangePeriapsis(apo, allNodes[allNodes:length-1]:orbit, safety).
    }
}

// add node if dv is high enough
print "Adding third node...".
addNode(node3).