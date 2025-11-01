// version_check.ks
@lazyGlobal off.

parameter package.
parameter packageVersion.

function main{
    // Check if package exists
    local packagePath is "0:/build/" + package.
    if not exists(packagePath) {
        print "Package " + package + "not found in archive.".
        return.
    }

    local packageState is readJson(packagePath + "/state.json").
    if packageState:haskey("version") {
        if not(packageVersion = packageState["version"]) {
            print "Package" + package + "has version " + packageState["version"] + "available on the archive (current " + packageVersion + ").".
        }
    }
}

main().