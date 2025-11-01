// standard.ks is the standard boot file for most vessels
@lazyGlobal off.

// put at the top of most boot files:
print "Waiting for ship to unpack.".
wait until ship:unpacked.
print "Ship is now unpacked.".

// load rocket_state
local rocket_state is readJson("state.json").

// check package version against archive
if not addons:rt:available or addons:rt:hasKSCConnection(ship) {
    print "Checking for package updates...".
    runOncePath("0:/src/pacman/version_check").
}

// create key execute_maneuver if none exists
if not rocket_state:hassuffix("execute_maneuver") {
    rocket_state:add("execute_maneuver", false).
}

// if execute_maneuver is true, jump into maneuver.ks
if rocket_state["execute_maneuver"] = true {
    runPath("1:/maneuver").
}