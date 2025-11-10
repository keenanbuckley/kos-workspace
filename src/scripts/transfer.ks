// transfer.ks creates the maneuver nodes to execute a Bi-elliptic transfer at the target patch
@lazyGlobal off.

// === PARAMETERS ===
parameter apo is -1.          // final apoapsis (defaults to targetPatch:apoapsis)
parameter peri is -1.         // final periapsis (defaults to targetPatch:apoapsis)
parameter rb is -1.           // intermediate apsis (defaults to Hohmann if -1)
parameter burn_anomoly is 0.  // true anomaly for first burn
parameter patchNum is 0.      // how many orbital patches from now to execute maneuver
parameter safety is true.     // prevent burns inside atmosphere or below surface

// define utility functions
runoncepath("0:/src/core/node").

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
if safety and burn_anomoly = 0 {
    if targetPatch:periapsis < 0 {
        print "Periapsis below surface, burn shifted to apoapsis.".
        set burn_anomoly to 180.
    } else if targetPatch:periapsis < targetPatch:body:atm:height and targetPatch:apoapsis > targetPatch:body:atm:height {
        print "Periapsis in atmosphere, burn shifted to apoapsis.".
        set burn_anomoly to 180.
    }
}

// === NODE 1: BURN TO INTERMEDIATE APSIS ===
local node1 is node(0,0,0,0).
local node1Alt is 0.

if hasNode {
    set node1 to nodeChangeApsis(rb, burn_anomoly, allNodes[allNodes:length-1]:orbit, safety).
    // compute radius at burn anomaly
    set node1Alt to allNodes[allNodes:length-1]:orbit:semimajoraxis * (1 - allNodes[allNodes:length-1]:orbit:eccentricity^2) / (1 + allNodes[allNodes:length-1]:orbit:eccentricity * cos(burn_anomoly)).
} else {
    set node1 to nodeChangeApsis(rb, burn_anomoly, targetPatch, safety).
    set node1Alt to targetPatch:semimajoraxis * (1 - targetPatch:eccentricity^2) / (1 + targetPatch:eccentricity * cos(burn_anomoly)).
}

print "Adding first node...".
addNode(node1).

// === NODE 2: BURN TO FINAL PERIAPSIS ===
local node2 is node(0,0,0,0).
if hasNode {
    // choose whether to adjust periapsis or apoapsis based on which is closer to node1Alt
    if abs(allNodes[allNodes:length-1]:orbit:periapsis - node1Alt) < abs(allNodes[allNodes:length-1]:orbit:apoapsis - node1Alt) {
        // set node2 to nodeChangeApsis(peri, 0, allNodes[allNodes:length-1]:orbit, safety).
        set node2 to nodeChangePeriapsis(peri, allNodes[allNodes:length-1]:orbit, safety).
    } else {
        // set node2 to nodeChangeApsis(peri, 180, allNodes[allNodes:length-1]:orbit, safety).
        set node2 to nodeChangeApoapsis(peri, allNodes[allNodes:length-1]:orbit, safety).
    }
} else {
    set node2 to nodeChangeApsis(peri, burn_anomoly, targetPatch, safety).
}
print "Adding second node...".
addNode(node2).

// === NODE 3: ONLY FOR TRUE BI-ELLIPTIC (rb != apo) ===
if not rb = apo {
    local node3 is node(0,0,0,0).
    if hasNode {
        if rb > apo {
            // set node3 to nodeChangeApsis(apo, 180, allNodes[allNodes:length-1]:orbit, safety).
            set node3 to nodeChangeApoapsis(apo, allNodes[allNodes:length-1]:orbit, safety).
        } else {
            // set node3 to nodeChangeApsis(apo, 0, allNodes[allNodes:length-1]:orbit, safety).
            set node3 to nodeChangePeriapsis(apo, allNodes[allNodes:length-1]:orbit, safety).
        }
    }
    print "Adding third node (bi-elliptic)...".
    addNode(node3).
} else {
    print "Hohmann transfer detected; skipping third node.".
}