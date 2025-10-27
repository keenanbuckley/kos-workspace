// wipe.ks
@lazyGlobal off.

print "Wiping drive...".

print("Before:").
list.

local fileList is list().
list files in fileList.
for f in fileList {
    deletePath("1:/" + f).
}

print("After:").
list.