// load core scripts
copyPath("0:/launch.ks", "").
if career:canMakeNodes {copyPath("0:/maneuver.ks", "").}.

//load utility scripts
copyPath("0:/utils/miscUtils", "").
if career:canMakeNodes {copyPath("0:/nodeUtils.ks", "").}.