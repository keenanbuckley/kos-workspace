// load core scripts
copyPath("0:/launch.ks", "").
if career():canMakeNodes {copyPath("0:/maneuver.ks", "").}.
if career():canMakeNodes {copyPath("0:/transfer.ks", "").}.

//load utility scripts
copyPath("0:/utils/miscUtils.ks", "utils/miscUtils.ks").
copyPath("0:/utils/engineUtils.ks", "utils/engineUtils.ks").
if career():canMakeNodes {copyPath("0:/utils/nodeUtils.ks", "utils/nodeUtils.ks").}.

// debug stuff
// runoncepath("utils/miscUtils.ks").
// print(getSpentNonRestartableEngines()).