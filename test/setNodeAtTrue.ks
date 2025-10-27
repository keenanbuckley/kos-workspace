// script to set a blank node at a specific true anomaly

parameter trueAnomaly. // True Anomaly in degrees

runOncePath("0:/lib/orbit").

runPath("0:/test/setNodeAtMean", trueAnomalyToMeanAnomaly(trueAnomaly, orbit:eccentricity)).