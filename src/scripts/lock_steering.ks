// lock_steering.ks locks the ship's steering to a particular
// body, persisting between vessel boots. Call lock_steering
// ("unlock") to disable.
@lazyGlobal off.

parameter targetBody is "unlock".

// load state
local state is lexicon().
set state to readJson("state.json").

// remove existing lock
if state:hassuffix("lock_steering") {
    print "Disabling lock_steering for " + state["lock_steering"].
    state:remove("lock_steering").
}

// set lock to direction of targetBody
if bodyExists(targetBody) {
    print "Locking steering to " + targetBody.
    lock steering to body(targetBody):direction.
    state:add("lock_steering", targetBody).
}

// save state
writeJson(state, "state.json").

// wait for user input to exit program
print "Press any key to exit...".
terminal:input:getchar().