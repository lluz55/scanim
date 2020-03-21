import threadpool
import os, tables
import strutils
import times


type
    FileStatus = enum
        None,
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
        listener: proc(watchStatus: FileStatus)
        waitExist: bool
        notFirstPass: bool
        lastAccess: Time
        status: FileStatus

var
    debug = false
    listenerCh*: Channel[Watched] ## Global channel variable needed
    registerCh: Channel[RegisterFile]
    filesToWatch: Table[string, FileWatched]
    filesWatched: Table[string, proc(status: FileStatus)]


listenerCh.open() ## Initialize channel
registerCh.open()


#TODO: add option to log to file
#TODO: add option to use epoch format
template log(msgs: varargs[string]) =
    let t = now()
    if debug: stdout.writeLine(t.hour, ":", t.minute, ":", t.second, " ",
            msgs.join(" "))


proc watchFile*(file: string, listener: proc(watchStatus: FileStatus),
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


proc runAsync(){.thread.} =
    ## Send data through channel
    var isReady: bool
    var regMsg: RegisterFile
    while true:
        # listenerCh.send(("filename",None))
        (isReady, regMsg) = registerCh.tryRecv()
        if isReady:
            echo regMsg.filename, " registered"
            listenerCh.send(("teste.txt", UnknownError))
        sleep(1000)


# TODO: Implement callback. Store callbacks inside a variable
# TODO:
proc registerFile(filename: string, waitExists: bool, cb: proc(
        status: FileStatus)) =
    if not filesWatched.contains(filename):
        filesWatched[filename] = cb
        registerCh.send((filename, waitExists))
        echo "registering '", filename, "' ..."

spawn runAsync()

var
    isReady: bool
    chMsg: Watched
    lap = 0

registerFile("teste.txt", false, proc(status: FileStatus) =
    echo "status update: ", status
)

while true:
    (isReady, chMsg) = listenerCh.tryRecv()

    if isReady:
        if chMsg.filename == "teste.txt":
            echo "fn: ", chMsg.filename


    echo "main thread"
    inc lap
    sleep(500)

sync() # waits forever
