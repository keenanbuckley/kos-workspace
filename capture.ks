//transfer
// this script creates a maneuver node to capture around a body

declare parameter opp is -1.
declare parameter conj is -1.
declare parameter patchNum is 1.
declare parameter execute is false.

// define utility functions
runoncepath("lib/node.ks").

// find target orbit
set targetPatch to orbit.
FROM {local i is 0.} UNTIL i = patchNum STEP {set i to i+1.} DO {
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
    run transfer(opp, conj, execute, targetPatch).
}