## ### Helper library for others libraries
## Basic usage example
##
## .. code-block:: bash
##  git clone https://github.com/lluz55/scanim.git
##  cd scanim/example
##  nim c -r -p:../ watcher.nim


from os import getFileInfo, sleep
from strutils import join
from times import Time, now
import tables

type
    WatchStatus* = enum
        None
        FileNotExistError,
        UnknownError
        Edited,
        MovedDeleted
    FileWatched = ref object
        listener: proc(watchStatus: WatchStatus)
        waitExist: bool
        notFirstPass: bool
        lastAccess: Time
        status: WatchStatus

var
    debug = false
    filesToWatch = initTable[string, FileWatched]()
    watchInterval = 1000
    toBeRemoved: seq[string]
    toBeAdded = initTable[string, FileWatched]()

#TODO: add option to log to file
#TODO: add option to use epoch format
template log(msgs: varargs[string]) =
    let t = now()
    if debug: stdout.writeLine(t.hour, ":", t.minute, ":", t.second, " ",
            msgs.join(" "))

proc watchFileInternal(file: string, fw: FileWatched) =
    try:
        let fInfo = getFileInfo(file)
        if not fw.notFirstPass:
            fw.lastAccess = fInfo.lastWriteTime
            log("\tWatching file:", file)
        else:
            if fInfo.lastWriteTime != fw.lastAccess:
                fw.lastAccess = fInfo.lastWriteTime
                log("\tFile", file, "has changed")
                fw.listener(Edited)
        fw.notFirstPass = true
    except:
        var timeChk: Time
        if fw.lastAccess == timeChk:
            fw.notFirstPass = false
            if fw.status != FileNotExistError:
                fw.status = FileNotExistError
                log("\tFile", file, "doesn't exists")
                fw.status = FileNotExistError
                if not fw.waitExist:
                    toBeRemoved.add(file)
                fw.listener(FileNotExistError)
        else:
            if fw.status != MovedDeleted:
                fw.status = MovedDeleted
                log("\tFile", file, "has been moved/deleted")
                if not fw.waitExist:
                    toBeRemoved.add(file)
                fw.listener(MovedDeleted)

#TODO: Add option for MD5 check
proc watchFile*(file: string, listener: proc(watchStatus: WatchStatus),
        waitExist = false) =
    ## Watches for changes in a file.
    ##
    ## `file`: file name.
    ##
    ## `listener`: callback that will be called when the file changed.
    ##
    ## `waitExist`: file does not exist at beginning but will be moved or created at that location.

    if not filesToWatch.contains(file):
        let fw = FileWatched(listener: listener, waitExist: waitExist)
        toBeAdded[file] = fw
    else:
        log("File", file, "already been watched")


proc setDebug*(on: bool) =
    ## Set dubug. Defaults `false`
    debug = on

proc run() =
    while true:
        for fn, fw in filesToWatch:
            watchFileInternal(fn, fw)
        sleep(watchInterval)
        for tbr in toBeRemoved:
            filesToWatch.del(tbr)
        for fn, tba in toBeAdded:
            filesToWatch[fn] = tba
        toBeAdded.clear()

template watchFiles*(assignment: untyped) =
    ## Wraps `watchFile` s calls to make sure that it will watch all files at the end
    log("Starting...")
    assignment
    run()
