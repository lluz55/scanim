import threadpool
import os, tables
import strutils
import times


type
    FileStatus = enum
        None
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
        # listener: proc(watchStatus: FileStatus)
        waitExist: bool
        notFirstPass: bool
        lastAccess: Time
        status: FileStatus

var
    debug = false
    listenerCh: Channel[Watched] ## Global channel variable needed
    registerCh: Channel[RegisterFile]
    filesToWatch {.threadVar.}: Table[string, FileWatched]
    filesWatched {.threadVar.}: Table[string, proc(status: FileStatus)]
    watchInterval = 1000


listenerCh.open() ## Initialize channel
registerCh.open()


#TODO: add option to log to file
#TODO: add option to use epoch format
template log(msgs: varargs[string]) =
    let t = now()
    if debug: stdout.writeLine(t.hour, ":", t.minute, ":", t.second, " ",
            msgs.join(" "))

proc watchFile(file: string, fw: FileWatched) {.thread.} =
    try:
        let fInfo = getFileInfo(file)
        if not fw.notFirstPass:
            fw.lastAccess = fInfo.lastWriteTime
            log("Watching file:", file)
        else:
            if fInfo.lastWriteTime != fw.lastAccess:
                fw.lastAccess = fInfo.lastWriteTime
                log("File", file, "has changed")
                listenerCh.send((file, Changed))
                # fw.listener(Changed)
        fw.notFirstPass = true
    except:
        var timeChk: Time
        if fw.lastAccess == timeChk:
            fw.notFirstPass = false
            if fw.status != FileNotFoundError:
                fw.status = FileNotFoundError
                log("File", file, "doesn't exists")
                fw.status = FileNotFoundError
                # if not fw.waitExist:
                #     toBeRemoved.add(file)
                # fw.listener(FileNotFoundError)
                listenerCh.send((file, FileNotFoundError))
        else:
            if fw.status != DeletedMoved:
                fw.status = DeletedMoved
                log("File", file, "has been moved/deleted")
                # if not fw.waitExist:
                #     toBeRemoved.add(file)
                # fw.listener(DeletedMoved)
                listenerCh.send((file, DeletedMoved))


proc runAsync(){.thread.} =
    ## Send data through channel
    var isReady: bool
    var regMsg: RegisterFile
    while true:
        # listenerCh.send(("filename",None))
        (isReady, regMsg) = registerCh.tryRecv()
        if isReady:
            let fw = FileWatched(waitExist: regMsg.waitExists)
            filesToWatch[regMsg.filename] = fw
            log(regMsg.filename.capitalizeAscii(), " registered")
        for fn, fw in filesToWatch:
            watchFile(fn, fw)
        sleep(watchInterval)


proc checkEvents() =
    let (isReady, chMsg) = listenerCh.tryRecv()
    if isReady:
        if filesWatched.contains(chMsg.filename):
            filesWatched[chMsg.filename](chMsg.status)


proc setDebug*(on: bool) =
    ## Set dubug. Defaults `false`
    debug = on

template watcherLoop(interval = 0, body: untyped) =
    while true:
        checkEvents()
        body
        sleep(interval)


proc registerFile(filename: string, waitExists: bool, cb: proc(
        status: FileStatus)) {.thread.} =
    if not filesWatched.contains(filename):
        filesWatched[filename] = cb
        registerCh.send((filename, waitExists))
        log("Registering '", filename, "'...")


#---------------------- Example of use ----------------------#

spawn runAsync()

registerFile("test.txt", false, proc(status: FileStatus) =
    echo "status update: ", status
)

watcherLoop(1000) do:
    discard