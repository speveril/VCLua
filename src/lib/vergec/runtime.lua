-- Run time functions for VergeC

VergeC.runtime = {}

VergeC.runtime.op = {
    OP_LT = function(a,b) if a < b then return 1 else return 0 end end,
    OP_GT = function(a,b) if a > b then return 1 else return 0 end end,
    OP_LTE = function(a,b) if a <= b then return 1 else return 0 end end,
    OP_GTE = function(a,b) if a >= b then return 1 else return 0 end end,
    OP_AND = function(a,b) if VergeC.runtime.truth(a) and VergeC.runtime.truth(b) then return true else return false end end, 
    OP_OR = function(a,b) if VergeC.runtime.truth(a) or VergeC.runtime.truth(b) then return true else return false end end,
    OP_NOT = function(a) if VergeC.runtime.truth(a) then return 0 else return 1 end end
}

VergeC.runtime.libfunc = {
    log = function(this, str) this:emit('v3.log(') this:compileNode(str) this:emit(')') end,
}

VergeC.runtime.truth = function(a)
    if a == 0 or a == "" or a == false or a == nil then
        return false
    else
        return true
    end
end

