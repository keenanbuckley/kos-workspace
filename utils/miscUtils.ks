//misc_utils

function clearLine {
    parameter line.
    print "                                                    " at(0,line).
}

function getNonRestartableEngines {
    list engines in allEngines.
    set nonRestartableEngines to list().
    for eng in allEngines {
        if not eng:allowShutdown {
            nonRestartableEngines:add(eng).
        }
    }
    return nonRestartableEngines. 
}

// function getActiveNonRestartableEngines {
//     set nonRestartableEngines to getNonRestartableEngines().
//     set activeNonRestartableEngines to list().
//     for eng in nonRestartableEngines {
//         if eng:ignition and not eng:flameout {
//             activeNonRestartableEngines:add(eng).
//         }
//     }
//     return activeNonRestartableEngines.
// }

function getSpentNonRestartableEngines {
    set nonRestartableEngines to getNonRestartableEngines().
    set spentNonRestartableEngines to list().
    for eng in nonRestartableEngines {
        if eng:ignition and eng:flameout {
            spentNonRestartableEngines:add(eng).
        }
    }
    return spentNonRestartableEngines.
}