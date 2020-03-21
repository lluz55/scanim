import ../scanim
import threadpool

proc cb(change: WatchStatus) =
    echo change
    stdout.write("> ")


# Sync
# watchFiles:
#     watchFile("test.txt", cb)
#     watchFile("test2.txt", cb)

# watchFile("test.txt", cb)
# watchFile("test2.txt", cb)

# Async
var stm = spawn stdin.readLine()
stdout.write("> ")
watchFilesLoop(1000) do:
    if stm.isReady:
        watchFile(^stm, cb)
        stm = spawn stdin.readLine()
        stdout.write("> ")


