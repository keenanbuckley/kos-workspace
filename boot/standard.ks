// put at the top of most boot files:
print "Waiting for ship to unpack.".
wait until ship:unpacked.
print "Ship is now unpacked.".

// load update script if possible
copyPath("0:/update.ks", "").

// load rocket_state
local rocket_state is readJson("rocket_state.json").

// create key execute_maneuver if none exists
if not rocket_state:hassuffix("execute_maneuver") {
    rocket_state:add("execute_maneuver", false).
}

writeJson(rocket_state, "rocket_state.json").

// if execute_maneuver is true, jump into maneuver.ks
if rocket_state["execute_maneuver"] = true {
    run maneuver.
}