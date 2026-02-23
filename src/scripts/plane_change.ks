// plane_change.ks creates a maneuver node to match a target orbital plane
@lazyGlobal off.

parameter targetInc.
parameter targetLan.

runOncePath("0:/src/core/node").

print "Target: inc=" + round(targetInc, 2)
    + " lan=" + round(targetLan, 2).
local targetOrbit is createOrbit(
    targetInc, 0, orbit:semimajoraxis, targetLan, 0, 0,
    time:seconds, body).
local nd is nodeChangePlane(targetOrbit).
addNode(nd).
