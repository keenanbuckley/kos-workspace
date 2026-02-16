// debug_nodes.ks prints info about all maneuver nodes, orbits, and SOI transitions
@lazyGlobal off.

local function printOrbit {
    parameter label, orb.

    print label.
    print "  body=" + orb:body:name.
    if orb:eccentricity < 1 {
        print "  apo=" + round(orb:apoapsis) + " peri=" + round(orb:periapsis).
    } else {
        print "  peri=" + round(orb:periapsis) + " (hyperbolic)".
    }
    print "  ecc=" + round(orb:eccentricity, 6) + " sma=" + round(orb:semimajoraxis).
    if orb:eccentricity < 1 {
        print "  period=" + round(orb:period, 1) + "s".
    }
    print "  transition=" + orb:transition.
}

local function printPatches {
    parameter orb.

    local patch is orb.
    local depth is 0.
    until not patch:hasnextpatch {
        local trans is patch:transition.
        local next is patch:nextpatch.
        local etaStr is round(patch:nextpatcheta, 1).
        if trans = "ESCAPE" {
            print "  >> ESCAPE from " + patch:body:name
                + " to " + next:body:name
                + " in " + etaStr + "s".
        } else if trans = "ENCOUNTER" {
            print "  >> ENCOUNTER " + next:body:name
                + " in " + etaStr + "s".
        } else {
            print "  >> " + trans + " -> " + next:body:name
                + " in " + etaStr + "s".
        }
        printOrbit("  --- Patch " + depth + " (" + next:body:name + ") ---", next).
        set patch to next.
        set depth to depth + 1.
        if depth > 10 { print "  (patch limit reached)". break. }
    }
    if depth = 0 {
        print "  (no SOI changes)".
    }
}

printOrbit("--- Current Orbit ---", orbit).

if not hasNode {
    print "No maneuver nodes.".
    if orbit:hasnextpatch {
        print "SOI transitions from current orbit:".
        printPatches(orbit).
    }
} else {
    local i is 0.
    for nd in allNodes {
        print "--- Node " + i + " ---".
        print "  time=" + round(nd:time, 1) + " eta=" + round(nd:eta, 1) + "s".
        print "  pro=" + round(nd:prograde, 3)
            + " rad=" + round(nd:radialout, 3)
            + " nrm=" + round(nd:normal, 3).
        print "  dv=" + round(nd:deltav:mag, 3) + " m/s".
        printOrbit("  --- Post-Node Orbit ---", nd:orbit).
        printPatches(nd:orbit).
        set i to i + 1.
    }
    print "--- Final Orbit ---".
    local lastOrb is allNodes[allNodes:length-1]:orbit.
    // Walk to the very last patch.
    until not lastOrb:hasnextpatch {
        set lastOrb to lastOrb:nextpatch.
    }
    printOrbit("  (ultimate destination)", lastOrb).
}
