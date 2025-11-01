// standard.ks is the standard boot file for most vessels
@lazyGlobal off.

// put at the top of most boot files:
print "Waiting for ship to unpack.".
wait until ship:unpacked.
print "Ship is now unpacked.".

// load state
local state is lexicon().
set state to readJson("state.json").

// check package version against archive
if homeConnection:isconnected() and state:haskey("package") and state:haskey("version") {
    print "Checking for package updates...".
    runOncePath("0:/src/pacman/version_check", state["package"], state["version"]).
}

// create key execute_maneuver if none exists
if not state:hassuffix("execute_maneuver") {
    state:add("execute_maneuver", false).
}
writeJson(state, "state.json").

if state:hassuffix("lock_steering") {
    print "Locking steering to " + state["lock_steering"].
    lock steering to body(state["lock_steering"]):direction.
}

// if execute_maneuver is true, jump into maneuver.ks
if state["execute_maneuver"] = true {
    runPath("1:/maneuver").
}

// wait for user input to exit program
print "Press any key to exit...".
terminal:input:getchar().