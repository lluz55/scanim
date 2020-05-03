import threadpool
import os, tables
import strutils
import times

type    
    FileStatus = enum
        None
        Watching
        Created
        Changed
        DeletedMoved
        FileNotFoundError
        UnknownError
    RegisterFile = tuple
        filename: string
        waitExists: bool
    Watched = tuple
        filename: string
        status: FileStatus
    FileWatched = ref object
        waitExist: bool
        notFirstPass: bool
        lastAccess: Time
        lastTimeExist: bool
        status: FileStatus

var
    debug = false
    listenerCh: Channel[Watched]
    registerCh: Channel[RegisterFile]
    filesToWatch {.threadVar.}: Table[string, FileWatched]
    filesWatched {.threadVar.}: Table[string, proc(status: FileStatus)]
    # TODO(lluz): added filename in callback:
    # filesWatched {.threadVar.}: Table[string, proc(status: FileStatus, filename: string)]
    watchInterval = 1000
    keepWatching = true


listenerCh.open() ## Initialize channel
registerCh.open()


#TODO: add option to log to file
#TODO: add option to use epoch format
template log(msgs: varargs[string]) =
    let t = now()
    if debug: stdout.writeLine(t.monthday, "/", ord(t.month), "/", t.year, " ", t.hour, ":", t.minute, ":", t.second, " ",
            msgs.join(""))


proc watchFile(file: var string, fw: FileWatched) {.thread.} =
    try:
        let fInfo = getFileInfo(file)
        if not fw.notFirstPass:
            fw.lastAccess = fInfo.lastWriteTime
            fw.lastTimeExist = true
            if fw.status == FileNotFoundError and fw.waitExist:
                log("File <", file, "> has been created")
                listenerCh.send((move(file),Created))
            else:
                log("Watching file: <", file, ">")
                listenerCh.send((move(file),Watching))                
        else:
            if fInfo.lastWriteTime != fw.lastAccess:
                fw.lastAccess = fInfo.lastWriteTime
                if fw.lastTimeExist:
                    log("File <", file, "> has been changed")
                    fw.status = Changed
                    listenerCh.send((move(file), Changed))
                else:
                    log("File <", file, "> has been created")
                    fw.lastTimeExist = true
                    fw.status = Created
                    listenerCh.send((move(file), Created))

        fw.notFirstPass = true
    except:
        var timeChk: Time
        if fw.lastAccess == timeChk:
            fw.notFirstPass = false
            if fw.status != FileNotFoundError:
                fw.status = FileNotFoundError
                fw.lastTimeExist = false
                log("File <" , file, "> doesn't exists")
                listenerCh.send((move(file), FileNotFoundError))
        else:
            if fw.status != DeletedMoved:
                fw.status = DeletedMoved
                fw.lastTimeExist = false
                log("File <", file, "> has been moved/deleted")
                listenerCh.send((move(file), DeletedMoved))


proc checkEvents() =
    let (isReady, chMsg) = listenerCh.tryRecv()
    if isReady:
        if filesWatched.contains(chMsg.filename):
            filesWatched[chMsg.filename](chMsg.status)


proc setDebug*(on: bool) =
    ## Set dubug. Defaults `false`
    debug = on


proc runAsync*(){.thread.} =
    ## Send data through channel
    var isReady: bool
    var regMsg: RegisterFile
    while true:
        (isReady, regMsg) = registerCh.tryRecv()
        if isReady:
            let fw = FileWatched(waitExist: regMsg.waitExists)
            filesToWatch[regMsg.filename] = fw
            log("File <",regMsg.filename,">", " has been registered")
        for fn, fw in filesToWatch:
            var fnv = fn
            watchFile(fnv, fw)
        sleep(watchInterval)


template watcherLoop*(interval = 0, body: untyped) =
    while true:
        checkEvents()
        body
        sleep(interval)
        if not keepWatching:
            break


proc registerFile*(filename: string, waitExists: bool, cb: proc(
        status: FileStatus)) {.thread.} =
    var fname = filename
    if not filesWatched.contains(filename):
        filesWatched[fname] = cb
        registerCh.send((move(fname), waitExists))
        log("Registering <", filename, "> ...")


proc stopWatching*()=
    keepWatching = false


# -------------------------------------------------------------#
#                        Example of use                        #
# -------------------------------------------------------------#

when is_main_module:
    spawn runAsync() 

    registerFile("test.txt", true, proc(status: FileStatus) =
        echo "status update: ", status
    )

    watcherLoop(1000) do:
        discard
