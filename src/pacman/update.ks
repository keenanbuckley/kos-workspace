parameter fromBin is false.

local dir is "0:/".
if fromBin {
    runPath("0:/compile").
    set dir to "0:/bin/".
}

// load libraries
if not exists("lib") {createDir("lib"). }
copyPath(dir + "lib/terminal", "lib/").
copyPath(dir + "lib/engine", "lib/").
copyPath(dir + "lib/orbit", "lib/").

// load standard boot script
if not exists("boot") {createDir("boot"). }
copyPath(dir + "boot/standard", "boot/").

// load node scripts and libs
if career():canMakeNodes {copyPath(dir + "lib/node", "lib/").}.
if career():canMakeNodes {copyPath(dir + "lib/burn", "lib/").}.
if career():canMakeNodes {copyPath(dir + "maneuver", "").}.
if career():canMakeNodes {copyPath(dir + "transfer", "").}.
// if career():canMakeNodes {copyPath(dir + "capture", "").}.

// load launch and landing script
copyPath(dir + "launch", "").
copyPath(dir + "land", "").