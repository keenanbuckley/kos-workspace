parameter fromBin is false.

local dir is "0:/".
if fromBin {
    set dir to "0:/bin/".
}

// load core scripts
copyPath(dir + "launch", "").
if career():canMakeNodes {copyPath(dir + "maneuver", "").}.
if career():canMakeNodes {copyPath(dir + "transfer", "").}.
if career():canMakeNodes {copyPath(dir + "capture", "").}.

// load libraries
if not exists("lib") {createDir("lib"). }
copyPath(dir + "lib/terminal", "lib/").
copyPath(dir + "lib/engine", "lib/").
if career():canMakeNodes {copyPath(dir + "lib/node", "lib/").}.

// load standard boot script
if not exists("boot") {createDir("boot"). }
copyPath(dir + "boot/standard", "boot/").