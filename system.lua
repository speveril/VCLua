package.path = package.path .. ";src/?.lua;src/lib/?.lua;src/lib/?/init.lua"

require('vergec')

function autoexec()
    m = VergeC.loadfile("system.vc")
    
    VergeC.call('autoexec', {})
end