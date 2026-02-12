// terminal.ks provides functions for interacting with the terminal
@lazyGlobal off.

function clearLine {
    parameter line.
    print "                                                    " at(0,line).
}