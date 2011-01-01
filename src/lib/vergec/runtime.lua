-- Run time functions for VergeC

VergeC.runtime = {}

VergeC.runtime.op = {
    OP_LT = function(a,b) if a < b then return 1 else return 0 end end,
    OP_GT = function(a,b) if a > b then return 1 else return 0 end end,
    OP_LTE = function(a,b) if a <= b then return 1 else return 0 end end,
    OP_GTE = function(a,b) if a >= b then return 1 else return 0 end end,
    OP_AND = function(a,b) if VergeC.runtime.truth(a) and VergeC.runtime.truth(b) then return true else return false end end, 
    OP_OR = function(a,b) if VergeC.runtime.truth(a) or VergeC.runtime.truth(b) then return true else return false end end,
    OP_NOT = function(a) if VergeC.runtime.truth(a) then return 0 else return 1 end end,
    OP_BSL = function(a,b) return bit.blshift(a,b) end,
    OP_BSR = function(a,b) return bit.brshift(a,b) end,
    OP_BAND = function(a,b) return bit.band(a,b) end,
    OP_BOR = function(a,b) return bit.bor(a,b) end,
    OP_BXOR = function(a,b) return bit.bxor(a,b) end,
    OP_BNOT = function(a) return bit.bnot(a,b) end
}

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
    end
}

VergeC.runtime.truth = function(a)
    if a == 0 or a == "" or a == false or a == nil then
        return false
    else
        return true
    end
end

