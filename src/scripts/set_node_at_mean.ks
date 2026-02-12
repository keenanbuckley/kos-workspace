// set_node_at_mean.ks sets a blank node at a specific mean anomaly
@lazyGlobal off.

parameter meanAnomaly. // Mean Anomaly in degrees

// calculate time difference between maneuver and periapsis
local maneuverTimePeri is (meanAnomaly / 360) * orbit:period.

// calculate time since craft last passed periapsis
local shipTimePeri is orbit:period - eta:periapsis.
if eta:periapsis < 0 {
    set shipTimePeri to eta:periapsis.
}

// calculate time until maneuver node
local maneuverEtaRelative is maneuverTimePeri - shipTimePeri.
if maneuverTimePeri < shipTimePeri {
    set maneuverEtaRelative to eta:periapsis + maneuverTimePeri.
}

// calculate absolute time of maneuver node
local maneuverEtaAbsolute is time:seconds + maneuverEtaRelative.

// place maneuver node
local myNode is node(maneuverEtaAbsolute, 0, 0, 0).
add myNode.