-- Run time functions for VergeC

VergeC.runtime = {}

VergeC.runtime.lookupBuiltin = function(var)
    if v3[var] ~= not nil then
        return true,'int'
    end
    
    return nil
end

VergeC.runtime.op = {
    -- Comparisons
    OP_LT = function(...)
        local args={...}; local i;
        for i=2,#args,2 do if (args[i] == 'OP_LT' and not (args[i-1] < args[i+1])) or (args[i] == 'OP_LTE' and not (args[i-1] <= args[i+1])) then return 0 end end;
        return 1
    end,
    OP_GT = function(...)
        local args={...}; local i;
        for i=2,#args,2 do if (args[i] == 'OP_GT' and not (args[i-1] > args[i+1])) or (args[i] == 'OP_GTE' and not (args[i-1] >= args[i+1])) then return 0 end end;
        return 1
    end,
    OP_EQ = function(...)
        local args={...}; local i;
        for i=2,#args,2 do if args[i-1] ~= args[i+1] then return 0; end end;
        return 1
    end,
    
    -- Logical operators
    OP_AND = function(a,op,b) if VergeC.runtime.truth(a) and VergeC.runtime.truth(b) then return true else return false end end, 
    OP_OR = function(a,op,b) if VergeC.runtime.truth(a) or VergeC.runtime.truth(b) then return true else return false end end,
    OP_NOT = function(a) if VergeC.runtime.truth(a) then return 0 else return 1 end end,
    
    -- Bitwise operators
    OP_BSL = function(a,op,b) return bit.blshift(a,b) end,
    OP_BSR = function(a,op,b) return bit.brshift(a,b) end,
    OP_BAND = function(a,op,b) return bit.band(a,b) end,
    OP_BOR = function(a,op,b) return bit.bor(a,b) end,
    OP_BXOR = function(a,op,b) return bit.bxor(a,b) end,
    OP_BNOT = function(a) return bit.bnot(a,b) end
}

-- aliases; these generally take in the ops for chaining purposes
VergeC.runtime.op.OP_LTE = VergeC.runtime.op.OP_LT
VergeC.runtime.op.OP_GTE = VergeC.runtime.op.OP_LT


VergeC.runtime.lib = {
    -- fill with library funcs that need special handling, or I'm just adding
    bitstring = function(a,width)
        local s = string.reverse(table.concat(bit.tobits(a)))
        
        if width then
            if string.len(s) < width then
                s = string.rep("0", width - string.len(s)) .. s
            elseif string.len(s) > width then
                s = string.sub(s, -width)
            end
        end
        
        return s
    end,
    
    str = function(a) return tostring(a) end,
    int = function(a) return Math.floor(a) end,
    
    map = function(filename)
        v3.log("OKAY TRYING TO LOAD A MAP... " .. filename)
        
        if VergeC.runtime.mapmodule then
            v3.log("Unloading old map code")
            VergeC.runtime.mapmodule:unload()
        end
        
        local vcfilename = string.sub(filename, 1, -4) .. "vc"
        v3.log("Going to load " .. vcfilename)
        
        VergeC.runtime.mapmodule = VergeC.loadfile(vcfilename)
        
        v3.hookMapLoad(VergeC.runtime.lib.mapLoad)
        v3.map(filename)
    end,
    
    mapLoad = function()
        v3.log(v3.curmap.zones);
        
        local i
        for i=0,v3.curmap.zones do
            if v3.zone[i].event ~= '' then
                v3.zone[i].event = "VergeC.bin[\"" .. v3.zone[i].event .. "\"]"
            end
        end
        
        for i=0,v3.entities do
            if v3.entity[i].script and v3.entity[i].script ~= '' then
                v3.entity[i].rawscript = v3.entity[i].script
                v3.entity[i].script = "__wrapEntityFunc"
            end
        end        
       
        startupscript = string.lower(v3.curmap.startupscript)
        if VergeC.bin[startupscript] then
            VergeC.bin[startupscript]()
        end
    end
}

function __wrapEntityFunc()
    local e = v3.event.entity
    local s = v3.entity[e].rawscript
    
    v3.log("Entity event with entity " .. v3.entity[e].description .. ", trying to call " .. s)
    
    if _G[s] then
        v3.log("Calling global '" .. s .. "'")
        _G[s]()
    elseif VergeC.bin[string.lower(s)] then
        v3.log("Calling VC func '" .. s .. "'")
        VergeC.call(string.lower(s))
    end
end

VergeC.runtime.truth = function(a)
    if a == 0 or a == "" or a == false or a == nil then
        return false
    else
        return true
    end
end



t = getmetatable(_G)
if not t then t = {} end
t.__index = VergeC.bin
setmetatable(_G, t)