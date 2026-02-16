// plane_change.ks creates a maneuver node to match another orbit's plane
@lazyGlobal off.

parameter targetOrbit.

runOncePath("0:/src/core/node").

if not targetOrbit:istype("Orbit") {
    print "Error: expected an Orbit (e.g. minmus:orbit).".
} else {
    print "Target: inc=" + round(targetOrbit:inclination, 2)
        + " lan=" + round(targetOrbit:lan, 2).
    local nd is nodeChangePlane(targetOrbit).
    addNode(nd).
}
