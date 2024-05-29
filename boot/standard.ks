// put at the top of most boot files:
print "Waiting for ship to unpack.".
wait until ship:unpacked.
print "Ship is now unpacked.".

// load update script if possible
copyPath("0:/update.ks", "").