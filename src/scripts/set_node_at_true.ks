// set_node_at_true.ks sets a blank node at a specific true anomaly
@lazyGlobal off.

parameter trueAnomaly. // True Anomaly in degrees

runOncePath("0:/src/core/orbit").

runPath("0:/src/scripts/set_node_at_mean", trueAnomalyToMeanAnomaly(trueAnomaly, orbit:eccentricity)).