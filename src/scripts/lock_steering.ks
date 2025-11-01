// lock_steering.ks locks the ship's steering to a particular
// body, persisting between vessel boots. Call lock_steering
// ("unlock") to disable.
@lazyGlobal off.

parameter target_body is "unlock".

// load state
local state is lexicon().
set state to readJson("state.json").

// remove existing lock
if state:hassuffix("lock_steering") {
    print "Disabling lock_steering for " + state["lock_steering"].
    state:remove("lock_steering").
}

// set lock to direction of target_body
if bodyExists(target_body) {
    print "Locking steering to " + target_body.
    lock steering to body(target_body):direction.
    state:add("lock_steering", target_body).
}

// save state
writeJson(state, "state.json").

// wait for user input to exit program
print "Press any key to exit...".
terminal:input:getchar().