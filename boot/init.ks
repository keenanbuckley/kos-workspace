// load update script
copyPath("0:/update.ks", "").

// remove init boot script
deletePath("boot/init.ks").

// run update
run update.

// set standard to be the new boot script
set core:bootfilename to "boot/standard.ks".

// reboot system to start with the new boot file
reboot.