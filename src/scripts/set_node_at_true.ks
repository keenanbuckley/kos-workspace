// set_node_at_true.ks sets a blank node at a specific true anomaly
@lazyGlobal off.

parameter trueAnomaly. // True Anomaly in degrees

runOncePath("0:/src/core/orbit").

local nodeEta is etaToTrueAnomaly(trueAnomaly).
add node(time:seconds + nodeEta, 0, 0, 0).
