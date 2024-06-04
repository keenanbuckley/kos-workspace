// load update script
copyPath("0:/update.ks", "").

// remove init boot script
deletePath("boot/init_ksm.ks").

// run update
run update(True).

// create rocket state lexicon
set rocket_state to lexicon().
writeJson(rocket_state, "rocket_state.json").

// set standard to be the new boot script
set core:bootfilename to "boot/standard".

// reboot system to start with the new boot file
reboot.