import threadpool
import os, tables
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
    listenerCh*: Channel[Watched] ## Global channel variable needed
    registerCh: Channel[RegisterFile]
    filesToWatch: Table[string, FileWatched]
    filesWatched: Table[string, proc(status: FileStatus)]


listenerCh.open() # TODO: EXTERNAL
                  # Initialize channel
registerCh.open()

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

var lap = 0

registerFile("teste.txt", false, proc(status: FileStatus)=
    echo "status update: ", status
)

while true:
    (isReady, chMsg) = listenerCh.tryRecv()
    if lap == 3:
        
    if isReady:
        if chMsg.filename == "teste.txt":
            echo "fn: ", chMsg.filename


    echo "main thread"
    inc lap
    sleep(500)

sync() # waits forever
