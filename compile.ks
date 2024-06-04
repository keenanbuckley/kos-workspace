// compile will compile all ks scripts in the boot, root, and lib directories, and place them into bin

function compileDir {
    parameter fileList.
    parameter dest.

    for file in fileList {
        if file:extension = "ks" {
            compile file to dest + file:name:replace(".ks", ".ksm").
        }
    }
}

cd("0:/").
list files in rootList.
compileDir(rootList, "bin/").

cd("0:/lib").
list files in libList.
compileDir(libList, "../bin/lib/").
cd("..").

cd("0:/boot").
list files in bootList.
compileDir(bootList, "../bin/boot/").