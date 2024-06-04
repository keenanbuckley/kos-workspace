// compile will compile all ks scripts in the boot, root, and lib directories, and place them into bin

function compileDir {
    parameter fileList.
    parameter dest.

    for file in fileList {
        if file:matchesPattern("^[^.]*\.ks$") {
            compile file to dest + file:replace(".ks", ".ksm").
        }
    }
}

list files in rootList.
compileDir(rootList, "bin/").

cd("lib").
list files in libList.
compileDir(libList, "../bin/lib").
cd("..").

cd("boot").
list files in bootList.
compileDir(bootList, "../bin/boot").