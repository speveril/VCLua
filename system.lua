package.path = package.path .. ";src/?.lua;src/lib/?.lua;src/lib/?/init.lua"

require('vergec')

function autoexec()
    local w = v3.imageWidth(v3.screen)
    local h = v3.imageHeight(v3.screen)
    v3.rectFill(0, 0, w - 1, h - 1, 0, v3.screen)
    v3.printString(0, 0, v3.screen, 0, "Compiling VergeC, please wait...")
    v3.showPage()
    
    m = VergeC.loadfile("system.vc")
    VergeC.call('autoexec', {})
end
