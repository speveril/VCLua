package.path = package.path .. ";src/?.lua;src/lib/?.lua;src/lib/?/init.lua"

require('vergec')

function autoexec()
    VergeC.loadfile("system.vc")
    --VergeC.call('autoexec', {})

    print("")
    v3.log("done")
end