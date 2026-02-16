// set_node_at_mean.ks sets a blank node at a specific mean anomaly
@lazyGlobal off.

parameter meanAnomaly. // Mean Anomaly in degrees

local maneuverTimePeri is 0.
if orbit:eccentricity < 1 {
    set maneuverTimePeri to (meanAnomaly / 360) * orbit:period.
} else {
    set maneuverTimePeri to meanAnomaly * constant:degtorad
        * sqrt((-orbit:semimajoraxis)^3 / orbit:body:mu).
}

local nodeEta is maneuverTimePeri + orbit:eta:periapsis.
if orbit:eccentricity < 1 {
    set nodeEta to mod(nodeEta, orbit:period).
    if nodeEta < 0 { set nodeEta to nodeEta + orbit:period. }
}

local myNode is node(time:seconds + nodeEta, 0, 0, 0).
add myNode.
