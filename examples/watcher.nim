import scanim

proc cb(change: WatchStatus) =
    echo change


watchFiles:
    watchFile("test.txt", cb)
    watchFile("test2.txt", cb)
