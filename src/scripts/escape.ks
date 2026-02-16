// escape.ks creates a prograde node at periapsis to escape the current SOI
@lazyGlobal off.

parameter vSOI is 0.

runOncePath("0:/src/core/node").

if orbit:eccentricity >= 1 {
    print "Already on escape trajectory (ecc=" + round(orbit:eccentricity, 4) + ").".
} else {
    print "Escaping " + body:name + " -> " + body:orbit:body:name.
    print "v_soi=" + round(vSOI, 2) + " m/s".

    local nd is nodeEscape(vSOI).
    addNode(nd).
}
