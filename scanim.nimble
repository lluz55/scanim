version     = "0.1.0"
author      = "Lucas Luz"
description = "An file and directory watcher"
license     = "MIT"
skipDirs    = @["docs"]

bin = @["scanim"]
requires "nim >= 1.3.1"

# Tests

task test, "Runs the test suste":
    
    exec "nim c -r --threads:on tests/tscanim_async"
    # rmFile("tests/tscanim_async".toExe())