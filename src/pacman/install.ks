// install.ks
@lazyGlobal off.

parameter package is "".
parameter packageVersion is "latest".
parameter compile is "true".
parameter force is false.
parameter bootFilePath is "boot/default".

function compileDir {
    parameter fileList.
    parameter dest.

    for file in fileList {
        if file:isfile and file:extension = "ks" {
            compile file to dest + file:name:replace(".ks", ".ksm").
        }
    }
}

function copyDir {
    parameter fileList.
    parameter dest.

    for file in fileList {
        if file:isfile {
            copyPath(file, dest + file:name).
        }
    }
}

function main {
    // Load peristent state
    local state is lexicon().
    if exists("state.json") {
        print "Loading persistent state...".
        set state to readJson("state.json").
    }

    // Package Check
    local packagePath is "0:/build/" + package.
    if not exists(packagePath) {
        print "Package not found and/or missing. Skipping installation.".
        return.
    }

    // Notify if different package installed than target
    if state:haskey("package") and not(state["package"] = package) {
        print("Warning: Replacing package " + state["package"] + " with " + package).
    }

    // Notify if different compile option set than target
    if state:haskey("compile") and not(state["compile"] = compile) {
        print("Warning: Changing compile setting from " + state["compile"] + " to " + compile).
    }

    // Check that user wants to install package
    if not force {
        print("Do you want to install this package? (Y/n)").
        local installConfirm is true.
        local ch is terminal:input:getchar().
        if not(ch = terminal:input:return) {
            set installConfirm to false.
            until ch = terminal:input:return {
                if ch = "y" or ch = "Y" {
                    set installConfirm to true.
                }
                set ch to terminal:input:getchar().
            }
        }
        if not(installConfirm) {
            print "Installation cancelled.".
            return.
        }
    }

    // Version check
    print "Starting package installation...".
    if state:haskey("version") {
        local oldVer is state["version"].
        if not(packageVersion = "latest") and oldVer = packageVersion {
            print "Package already at version " + oldVer + ". Skipping installation.".
            return.
        } else {
            print "Updating from version " + oldVer + " to " + packageVersion + ".".
        }
    } else {
        print "Fresh install (no previous version detected).".
    }
    set state["version"] to packageVersion.

    // Delete existing files // TODO: Only delete code files
    runPath("0:/src/pacman/wipe").

    // Switch to Workspace
    switch to archive.

    // Step 1: Compile and Deploy Package Library Files
    print "Installing libraries...".
    cd(packagePath + "/lib").
    local filelist is list().
    list files in filelist.
    if compile {
        compileDir(filelist, "1:/lib/").
    } else {
        copyDir(filelist, "1:/lib/").
    }

    // Step 2: Compile and Deploy Package Boot Files
    print "Installing boot files...".
    cd(packagePath + "/boot").
    list files in filelist.
    if compile {
        compileDir(filelist, "1:/boot/").
    } else {
        copyDir(filelist, "1:/boot/").
    }

    // set bootFilePath to be the new boot script
    set core:bootfilename to bootFilePath.

    // Step 3: Compile and Deploy Package Offline Scripts
    print "Installing offline scripts...".
    cd(packagePath + "/offline_scripts").
    list files in filelist.
    if compile {
        compileDir(filelist, "1:/").
    } else {
        copyDir(filelist, "1:/").
    }

    // Step 4: Compile and Deploy Package Online Scripts
    // Note: Online scripts should simply call an archive 
    // script, so are too small to ever justify compiling.
    print "Installing online scripts...".
    cd(packagePath + "/online_scripts").
    list files in filelist.
    copyDir(filelist, "1:/").

    // Switch back to CPU
    switch to 1.

    // Step 5: Save persistent state file
    writeJson(state, "state.json").

    print "Installation complete (v:" + packageVersion + "). Reboot recommended.".
}

main().