function string.split(str, div)
    if (div=='') then return false end
    local pos,arr = 0,{}
    -- for each divider found
    for st,sp in function() return string.find(str,div,pos,true) end do
        table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
        pos = sp + 1 -- Jump past current divider
    end
    table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
    return arr
end

VergeC.typedefs = {}
VergeC.compatibleOperators = {       -- it is assumed that an operator is compatible with itself
    OP_GT={'OP_GTE'}, OP_GTE={'OP_GT'},
    OP_LT={'OP_LTE'}, OP_LTE={'OP_LT'},
    OP_ADD={'OP_SUB'}, OP_SUB={'OP_ADD'},
    OP_MLT={'OP_DIV','OP_MOD'},OP_DIV={'OP_MLT','OP_MOD'},OP_MOD={'OP_MLT','OP_DIV'},
    OP_CONCAT={'OP_ADD'} -- not really, but the add will get converted if we're looking at a CONCAT
}

print("### " .. VergeC.compatibleOperators['OP_CONCAT'][1])

function VergeC.emit(this, str)
    this.compiledcode = this.compiledcode .. str
end

function VergeC.search(this, nodetype, start)
    if not start then start = this.ast end
    
    if start.type == nodetype then
        return start
    end
    
    local rtn = nil
    local i,v
    
    for i,v in ipairs(start) do
        rtn = this:search(nodetype, v)
        if rtn then break end
    end
    
    return rtn
end

function VergeC.compile(this)
    if not VergeC.scope then
        VergeC.scope = { {} }
    end
    
    this.scope = VergeC.scope
    this.ast = this:cleanNode(this.ast)
    
    VergeC.printAST(this.ast)
    
    this:compileNode(this.ast)
end

function VergeC.findVarInScope(this, varname)
    local refstr = varname

    level = #this.scope
    
    while level > 0 do
        if this.scope[level][varname] then
            if level == 1 then refstr = 'VergeC.bin.' .. refstr end
            return this.scope[level][varname], level, refstr
        end
        level = level - 1
    end
    
    if v3[varname] then
        return true, 0, "v3." .. varname
    end
    
    return nil
end

function VergeC.typeToString(type)
    if type == 'TY_VOID' then return 'void' end
    if type == 'TY_INT' then return 'int' end
    if type == 'TY_STRING' then return 'string' end
    return 'none'
end

function VergeC.getVarType(this, node)
    if not node then return end
    
    if node.vartype then return node.vartype end

    node.vartype = 'none'
    
    local name = {}
    if node.name then
        name = string.split(node.name, '/')
    end
    
    if node.type == 'TOKEN' then
        if node.token_type == 'STRING' then node.vartype = 'string'
        elseif node.token_type == 'NUMBER' then node.vartype = 'int'
        elseif node.token_type == 'IDENT' then
            local var = VergeC.findVarInScope(this, node.value)
            if var then
                node.vartype = var.type
            else
                this:error("Can't find var '" .. node.value .. "' in scope.")
            end
        end
    else
        if name[1] == 'func' then node.vartype = VergeC.typeToString(node[1].token_type)
        else node.vartype = this:getVarType(node[1])
        end
    end
    
    return node.vartype 
end

function VergeC.cleanNode(this, node)
    for i,v in ipairs(node) do
        node[i] = this:cleanNode(v)
    end
    return node
end

function VergeC.compileNode(this, node)
    if not node then return end
    
    --VergeC.printAST(node, 1, true)
    
    local name = {}
    if node.name then
        name = string.split(node.name, '/')
    end
    
    -- first deal with special names
    if name[1] == 'decl' then
        local scope = #this.scope
        
        if this.scope[scope][node[2]] then
            this:error("COMPILE ERROR\n  Redeclaration of variable '" .. node.name .. "'", node.index)
        else
            if name[2] == 'globalvar' then this:emit("VergeC.bin.") elseif name[2] == 'membervar' then this:emit("") else this:emit("local ") end
            this:emit(node[2].value .. " = ")
            
            local scopeentry = {}
            
            if node[1].token_type == 'IDENT' then
                if VergeC.typedefs[node[1].value] then
                    scopeentry = { type = node[1].value, ident = node[2].value }
                else
                    this:error("COMPILE ERROR\n  Unknown type '" .. node[1].value .. "' in declaration.", node.index)
                end
            else
                scopeentry = { type = node[1].token_type, ident = node[2].value }
            end
            
            if node[3].type == 'SEQ' then -- this means we have an array decl
                scopeentry.type = scopeentry.type .. "_ARRAY"
                if node[3][1].type ~= 'EMPTY' then
                    scopeentry.size = node[3][1].value
                end
            end
            this.scope[#this.scope][node[2].value] = scopeentry
            
            if node[4] then
                this:compileNode(node[4])
            else
                if string.sub(scopeentry.type, -6) == '_ARRAY' then
                    this:emit('{')
                    if scopeentry.size then
                        local first = true
                        for i=1,scopeentry.size do
                            if first then first = false else this:emit(',') end
                            if scopeentry.type == 'TY_INT_ARRAY' or scopeentry.type == 'TY_FLOAT_ARRAY' then
                                this:emit('0')
                            elseif scopeentry.type == 'TY_STRING_ARRAY' then
                                this:emit('""')
                            else
                                this:compileNode(VergeC.typedefs[string.sub(scopeentry.type, 1, -7)])
                            end
                        end
                    end
                    this:emit('}')
                elseif scopeentry.type == 'TY_INT' or scopeentry.type == 'TY_FLOAT' then
                    this:emit('0')
                elseif scopeentry.type == 'TY_STRING' then
                    this:emit('""')
                else
                    this:compileNode(VergeC.typedefs[scopeentry.type])
                end
            end
            
            if name[2] == 'globalvar' then this:emit(";\n") end
        end
        
    elseif name[1] == 'func' then
        -- currently we only support global functions
        if name[2] == 'globalfunc' then
            -- create new scope level
            local localscope = {}
            local params = {}
            
            table.insert(this.scope[1], { type = node[1].value, ident = node[2].value })
            table.insert(this.scope, localscope)
            
            -- build function head and signature
            local first = true
            this:emit("function VergeC.bin." .. node[2].value .. "(")
            for i,v in ipairs(node[3]) do
                if first then first = false else this:emit(",") end
                
                this:emit(v[2].value)
                table.insert(params, { type = v[1].token_type, ident = v[2].value, size = v[3].value, init = v[4] })
            end
            this:emit(")\n")
            
            -- do inits            
            for i,v in pairs(params) do
                localscope[v.ident] = v
                
                this:emit('if ' .. v.ident .. ' == nil then ' .. v.ident .. ' = ')
                if v.init then
                    this:compileNode(v.init)
                else
                    if node[1].token_type == 'TY_INT' or node[1].token_type == 'TY_FLOAT' then
                        this:emit('0')
                    elseif node[1].token_type == 'TY_STRING' then
                        this:emit('""')
                    end
                end
                this:emit(" end\n")
            end
            
            -- TODO need to enforce type on params somehow
            
            -- compile the function body
            if node[4] then this:compileNode(node[4]) end
            this:emit("end\n\n")
            
            -- pop off this function's scope
            table.remove(this.scope)
        end
    
    elseif name[1] == 'StructDecl' then
        VergeC.typedefs[node[1].value] = node
        node.name = 'Struct'   -- later we'll want this to be a Struct, not a StructDecl (see below)
        
    elseif name[1] == 'Struct' then
        this:emit('{')
        for i,v in ipairs(node[2]) do
            v.type = v.type .. '/membervar'
            this:compileNode(v)
            this:emit(";")
        end
        this:emit('}')
    
    elseif name[1] == 'IfStatement' then
        this:emit("if VergeC.runtime.truth(")
        this:compileNode(node[1])
        this:emit(") then \n")
        this:compileNode(node[2])
        for i = 3,#node do
            if node[i].name == 'elseif' then
                this:emit("elseif VergeC.runtime.truth(")
                this:compileNode(node[i][1])
                this:emit(") then\n")
                this:compileNode(node[i][2])
            else
                this:emit("else\n")
                this:compileNode(node[i][1])
            end
        end
        this:emit("end")
    
    elseif name[1] == 'WhileStatement' then
        table.insert(this.scope, {})
        this:emit('do\n') -- wrapping this in a do/end so we maintain a local scope
        this:emit("while VergeC.runtime.truth(")
        this:compileNode(node[1])
        this:emit(") do \n")
        this:emit("repeat\n")
        this:compileNode(node[2])
        this:emit("until true\n")
        this:emit("if VergeC.fullbreak then VergeC.fullbreak=false; break end\n")
        this:emit("end\n")
        this:emit('end')
        table.remove(this.scope)
    
    elseif name[1] == 'ForStatement' then
        table.insert(this.scope, {})
        this:emit('do\n') -- wrapping this in a do/end so we maintain a local scope
        this:compileNode(node[1])
        this:emit("\n")
        this:emit("while VergeC.runtime.truth(")
        this:compileNode(node[2])
        this:emit(") do \n")
        this:emit("repeat\n")
        this:compileNode(node[4])
        this:emit("until true\n")
        this:compileNode(node[3])
        this:emit(";\n")
        this:emit("if VergeC.fullbreak then VergeC.fullbreak=false; break end\n")
        this:emit("end\n")
        this:emit('end')
        table.remove(this.scope)
    
    elseif name[1] == 'statement' then
        this:compileNode(node[1])
        this:emit(";\n")
    
    elseif name[1] == 'FuncCall' then
        local funcname = node[1].value
        
        if VergeC.runtime.lib[funcname] then
            this:emit('VergeC.runtime.lib.' .. funcname .. '(')
            if node[2] then
                for i,v in ipairs(node[2]) do
                    if i > 1 then this:emit(", ") end
                    this:compileNode(v)
                end
            end
            this:emit(")")
        elseif v3[funcname] then
            this:emit("v3." .. funcname .. "(")
            if node[2] then
                for i,v in ipairs(node[2]) do
                    if i > 1 then this:emit(", ") end
                    this:compileNode(v)
                end
            end
            this:emit(")")
        else
            local first = true
            this:emit('VergeC.bin.' .. funcname .. '(')
            for i,v in ipairs(node[2]) do
                if first then first = false else this:emit(",") end
                this:compileNode(v)
            end
            this:emit(')')
        end
    
    elseif name[1] == 'return' then
        this:emit('do return ') -- wrap return in do ... end so we can return in the middle of a function
        this:compileNode(node[1])
        this:emit(' end')
        
    elseif name[1] == 'binop' then
        local operands = {}
        local childcount = #node
        local vartype = this:getVarType(node)
        
        if childcount == 3 then
            local lhs = node[1]
            local op = node[2].token_type
            local rhs = node[3]
            if vartype == 'string' and op == 'OP_ADD' then node[2].token_type = 'OP_CONCAT'; op = node[2].token_type end
            
            -- special case ops; in these cases we can't just let Lua do its default thing because
            -- VergeC has a different idea of how things work
            if VergeC.runtime.op[op] then
                this:emit('VergeC.runtime.op.' .. op .. '(') this:compileNode(lhs) this:emit(', ') this:emit(op) this:emit(', ') this:compileNode(rhs) this:emit(')')
            elseif op == 'OP_ASSIGN' then
                this:compileNode(lhs) this:emit(' = (') this:compileNode(rhs) this:emit(')')
            else
                this:emit('(') this:compileNode(lhs) this:emit(') ') this:compileNode(node[2]) this:emit(' (') this:compileNode(rhs) this:emit(') ')
            end
        else
            local opstep = false
            local lhs = null
            local op = null
            local rhs = null
            
            for i = 2,childcount,2 do
                local lhs = node[i - 1]
                local op = node[i].token_type
                local rhs = node[i + 1]
                
                if vartype == 'string' and op == 'OP_ADD' then node[i].token_type = 'OP_CONCAT'; op = node[i].token_type end
                
                if i == 2 and VergeC.runtime.op[op] then
                    this:emit('VergeC.runtime.op.' .. op .. '(')
                end
                
                -- do operator compatibility checks
                if node[i + 2] and op ~= node[i + 2].token_type then
                    local fail = true
                    local ii,vv
                    for ii,vv in ipairs(VergeC.compatibleOperators[op]) do
                        if node[i + 2].token_type == vv then fail = false; break end
                    end
                    
                    print(fail)
                    
                    if fail then
                        this:error("COMPILE ERROR:\n Incompatible operators.", node[i].index)
                    end
                end
                
                if VergeC.runtime.op[op] then
                    this:compileNode(lhs) this:emit(', "') this:emit(op) this:emit('", ')
                elseif op == 'OP_ASSIGN' then
                    this:compileNode(lhs) this:emit(' = ')
                else
                    this:emit('(') this:compileNode(lhs) this:emit(') ') this:compileNode(node[i]) this:emit(" ")
                end
                
                if i == childcount - 1 then
                    if not VergeC.runtime.op[op] then this:emit("(") end
                    this:compileNode(rhs)
                    this:emit(')')
                end
                
            end
        end
    
    elseif name[1] == 'preop' then
        if VergeC.runtime.op[node[1].token_type] then
            this:emit('VergeC.runtime.op.' .. node[1].token_type .. '(') this:compileNode(node[2]) this:emit(')')
        elseif node[1].token_type == 'OP_INCREMENT' or node[1].token_type == 'OP_DECREMENT' then
            -- this is hideous, let me explain...
            --  This creates a line something like this... ++x becomes
            --   (function() x = x + 1; return x; end)()
            --  What this does is creates a local function which has access to local
            --  variables of its parent. The function adds one to the variable, and
            --  then returns the new value. We CAN'T do this as a VergeC.runtime
            --  function, because there is no way to pass locals by reference in Lua.
            --  This local function is called immediately, thus producing the side
            --  effect AND getting the value.
            this:emit('(function() ')
            this:compileNode(node[2])
            this:emit(' = ')
            this:compileNode(node[2])
            if node[1].token_type == 'OP_INCREMENT' then this:emit(' + ')
            elseif node[1].token_type == 'OP_DECREMENT' then this:emit(' - ')
            end
            this:emit('1; return ')
            this:compileNode(node[2])
            this:emit('; end)()')
        else
            this:compileNode(node[1]) this:emit(' (') this:compileNode(node[2]) this:emit(') ')
        end

    elseif name[1] == 'postop' then
        if VergeC.runtime.op[node[2].token_type] then
            this:emit('VergeC.runtime.op.' .. node[2].token_type .. '(') this:compileNode(node[1]) this:emit(')')
        elseif node[2].token_type == 'OP_INCREMENT' or node[2].token_type == 'OP_DECREMENT' then
            -- See discussion in the preop block above. This works the same way except
            -- that it returns the original value rather than the new one.
            this:emit('(function() ')
            this:compileNode(node[1])
            this:emit(' = ')
            this:compileNode(node[1])
            if node[2].token_type == 'OP_INCREMENT' then this:emit(' + ')
            elseif node[2].token_type == 'OP_DECREMENT' then this:emit(' - ')
            end
            this:emit('1; return ')
            this:compileNode(node[1])
            if node[2].token_type == 'OP_INCREMENT' then this:emit(' - ')
            elseif node[2].token_type == 'OP_DECREMENT' then this:emit(' + ')
            end
            this:emit('1; end)()')
        else
            this:emit(' (') this:compileNode(node[1]) this:emit(') ') this:compileNode(node[2]) 
        end
    
    elseif name[1] == 'value' and #node > 1 then
        for i,v in ipairs(node) do
            if i > 1 then
                if v.token_type == 'IDENT' then
                    this:emit('.' .. v.value)
                else
                    this:emit('[1 + ')
                    this:compileNode(v)
                    this:emit(']')
                end
            else
                this:compileNode(v)
            end
        end
    
    -- then deal with generic types
    elseif node.type == 'EXPR' then
        this:compileNode(node[1])
    
    elseif node.type == 'TOKEN' then
        if node.token_type == 'NUMBER'
            or node.token_type == 'OP_ADD' or node.token_type == 'OP_SUB' or node.token_type == 'OP_MLT' or node.token_type == 'OP_DIV' or node.token_type == 'OP_MOD'
            or node.token_type == 'OP_ASSIGN' or node.token_type == 'OP_EQ'
            or node.token_type == 'OP_GT' or node.token_type == 'OP_LT' or node.token_type == 'OP_GTE' or node.token_type == 'OP_LTE'
        then
            this:emit(node.value)
        elseif node.token_type == 'OP_CONCAT' then
            this:emit("..")
        elseif node.token_type == 'OP_NE' then
            this:emit("~=")
        elseif node.token_type == 'STRING' then
            this:emit('"' .. node.value .. '"')
        elseif node.token_type == 'KEY_BREAK' then
            this:emit('do VergeC.fullbreak = true; break end')
        elseif node.token_type == 'KEY_CONTINUE' then
            this:emit('do break end')
        elseif node.token_type == 'IDENT' then
            local found, scopelevel
            found, scopelevel, refstr = VergeC.findVarInScope(this, node.value)
            if found then
                this:emit(refstr)
            else
                this:error("COMPILE ERROR\n  Unknown variable '" .. node.value .. "'.", node.index)
            end
        end
    
    elseif node.type == 'SEQ' then
        for i,v in ipairs(node) do
            this:compileNode(v)
        end
    end
end
