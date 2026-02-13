// transfer.ks creates the maneuver nodes to execute a Bi-elliptic transfer at the target patch
@lazyGlobal off.

// === PARAMETERS ===
parameter apo is -1.          // final apoapsis (defaults to targetPatch:apoapsis)
parameter peri is -1.         // final periapsis (defaults to targetPatch:apoapsis)
parameter rb is -1.           // intermediate apsis (defaults to Hohmann if -1)
parameter burnAnomaly is 0.  // true anomaly for first burn
parameter patchNum is 0.      // how many orbital patches from now to execute maneuver
parameter safety is true.     // prevent burns inside atmosphere or below surface

// define utility functions
runOncePath("0:/src/core/node").

// === SELECT TARGET PATCH ===
local targetPatch is orbit.
from {local i is 0.} until i = patchNum step {set i to i+1.} do {
    if targetPatch:hasnextpatch {
        set targetPatch to targetPatch:nextpatch.
    }
}

// === DEFAULT FINAL ORBIT ===
if apo = -1 { set apo to targetPatch:apoapsis. print "Final apoapsis set to " + apo. }
if peri = -1 { set peri to apo. print "Final periapsis set to " + peri. }

// === DEFAULT INTERMEDIATE APSIS ===
if rb = -1 or rb = apo {
    set rb to apo.  // Hohmann transfer by default
    print "Intermediate apsis = final apo, performing Hohmann transfer.".
}

// === SAFETY CHECKS ===
if safety and burnAnomaly = 0 {
    if targetPatch:periapsis < 0 {
        print "Periapsis below surface, burn shifted to apoapsis.".
        set burnAnomaly to 180.
    } else if targetPatch:periapsis < targetPatch:body:atm:height and targetPatch:apoapsis > targetPatch:body:atm:height {
        print "Periapsis in atmosphere, burn shifted to apoapsis.".
        set burnAnomaly to 180.
    }
}

// === NODE 1: BURN TO INTERMEDIATE APSIS ===
local node1 is node(0,0,0,0).
local node1Alt is 0.

if hasNode {
    set node1 to nodeChangeApsis(rb, burnAnomaly, allNodes[allNodes:length-1]:orbit, safety).
    // compute altitude at burn anomaly
    set node1Alt to allNodes[allNodes:length-1]:orbit:semimajoraxis * (1 - allNodes[allNodes:length-1]:orbit:eccentricity^2) / (1 + allNodes[allNodes:length-1]:orbit:eccentricity * cos(burnAnomaly)) - allNodes[allNodes:length-1]:orbit:body:radius.
} else {
    set node1 to nodeChangeApsis(rb, burnAnomaly, targetPatch, safety).
    set node1Alt to targetPatch:semimajoraxis * (1 - targetPatch:eccentricity^2) / (1 + targetPatch:eccentricity * cos(burnAnomaly)) - targetPatch:body:radius.
}

addNode(node1).

// === NODE 2: BURN TO FINAL PERIAPSIS ===
local node2 is node(0,0,0,0).
if hasNode {
    // burn at the apsis opposite node1Alt to adjust the final periapsis
    local burnTA is choose 180 if abs(allNodes[allNodes:length-1]:orbit:periapsis - node1Alt) < abs(allNodes[allNodes:length-1]:orbit:apoapsis - node1Alt) else 0.
    set node2 to nodeChangeApsis(peri, burnTA, allNodes[allNodes:length-1]:orbit, safety).
} else {
    set node2 to nodeChangeApsis(peri, burnAnomaly, targetPatch, safety).
}

addNode(node2).

// === NODE 3: ONLY FOR TRUE BI-ELLIPTIC (rb != apo) ===
if rb <> apo {
    local node3 is node(0,0,0,0).
    if hasNode {
        set node3 to nodeChangeApoapsis(apo, allNodes[allNodes:length-1]:orbit, safety).
    }
    addNode(node3).
} else {
    print "Hohmann transfer detected; skipping third node.".
}
