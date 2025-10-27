// script to set a blank node at a specific mean anomaly

parameter meanAnomaly. // Mean Anomaly in degrees

// calculate time difference between maneuver and periapsis
local maneuverTimePeri to (meanAnomaly / 360) * orbit:period.

// calculate time since craft last passed periapsis
local shipTimePeri to orbit:period - eta:periapsis.
if eta:periapsis < 0 {
    set shipTimePeri to eta:periapsis.
}

// calculate time until maneuver node
local maneuverEtaRelative to maneuverTimePeri - shipTimePeri.
if maneuverTimePeri < shipTimePeri {
    set maneuverEtaRelative to eta:periapsis + maneuverTimePeri.
}

// calculate absolute time of maneuver node
local maneuverEtaAbsolute to time:seconds + maneuverEtaRelative.

// place maneuver node
set myNode to node(maneuverEtaAbsolute, 0, 0, 0).
add myNode.