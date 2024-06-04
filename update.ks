// load core scripts
copyPath("0:/launch.ks", "").
if career():canMakeNodes {copyPath("0:/maneuver.ks", "").}.
if career():canMakeNodes {copyPath("0:/transfer.ks", "").}.
if career():canMakeNodes {copyPath("0:/capture.ks", "").}.

// load libraries
copyPath("0:/lib/terminal.ks", "lib/terminal.ks").
copyPath("0:/lib/engine.ks", "lib/engine.ks").
if career():canMakeNodes {copyPath("0:/lib/node.ks", "lib/node.ks").}.

// load standard boot script
copyPath("0:/boot/standard.ks", "boot/standard.ks").