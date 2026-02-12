// capture.ks creates a maneuver node to capture around a body
@lazyGlobal off.

parameter opp is -1.
parameter conj is -1.
parameter patchNum is 1.

// find target orbit
local targetPatch is orbit.
from {local i is 0.} until i = patchNum step {set i to i+1.} do {
    if targetPatch:hasnextpatch {
        set targetPatch to targetPatch:nextpatch.
    }
}

// this script only works if the targeted patch has a non elliptical trajectory
if targetPatch:eccentricity >= 1 {
    print "found valid patch for body: " + targetPatch:body:name.

    // if opposition or conjuction altitude was not set, set to periapsis
    if opp = -1 {
        set opp to targetPatch:periapsis.
        print "set opp to " + targetPatch:periapsis.
    }
    if  conj = -1 {
        set conj to targetPatch:periapsis.
        print "set conj to " + targetPatch:periapsis.
    }

    // create nodes
    runPath("0:/src/scripts/transfer", opp, conj, -1, 0, patchNum).
}