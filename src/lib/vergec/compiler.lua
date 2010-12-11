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

function VergeC.emit(this, str)
    this.compiledcode = this.compiledcode .. str
end

function VergeC.compile(this)
    print("COMPILE STEP")
    
    this.scope = { {} } -- scope[1] is global scope, which we always have
    
    this.ast = this:cleanNode(this.ast)
    this:compileNode(this.ast)
end

function VergeC.findVarInScope(this, varname)
    level = #this.scope
    
    while level > 0 do
        if this.scope[level][varname] then
            return this.scope[level][varname], level
        end
        level = level - 1
    end
    
    return nil, level
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
            VergeC.error("COMPILE ERROR\n  Redeclaration of variable '" .. node.name .. "'", node.index)
        else
            if name[2] ~= 'globalvar' then this:emit("local ") else this:emit("VergeC.bin.") end
            this:emit(node[2].value .. " = ")
            
            local scopeentry = { type = node[1].token_type, ident = node[2].value }
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
                if scopeentry.type == 'TY_INT_ARRAY' or scopeentry.type == 'TY_FLOAT_ARRAY' or scopeentry.type == 'TY_STRING_ARRAY' then
                    this:emit('{')
                    if scopeentry.size then
                        local first = true
                        for i=1,scopeentry.size do
                            if first then first = false else this:emit(',') end
                            if scopeentry.type == 'TY_INT_ARRAY' or scopeentry.type == 'TY_FLOAT_ARRAY' then
                                this:emit('0')
                            elseif scopeentry.type == 'TY_STRING_ARRAY' then
                                this:emit('""')
                            end
                        end
                    end
                    this:emit('}')
                elseif scopeentry.type == 'TY_INT' or scopeentry.type == 'TY_FLOAT' then
                    this:emit('0')
                elseif scopeentry.type == 'TY_STRING' then
                    this:emit('""')
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
    
    elseif name[1] == 'IfStatement' then
        this:emit("if VergeC.runtime.truth(")
        this:compileNode(node[1])
        this:emit(") then \n")
        this:compileNode(node[2])
        this:emit("end")
    
    elseif name[1] == 'WhileStatement' then
        table.insert(this.scope, {})
        this:emit('do\n') -- wrapping this in a do/end so we maintain a local scope
        this:emit("while VergeC.runtime.truth(")
        this:compileNode(node[1])
        this:emit(") do \n")
        this:compileNode(node[2])
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
        this:compileNode(node[4])
        this:compileNode(node[3])
        this:emit(";\n")
        this:emit("end\n")
        this:emit('end')
        table.remove(this.scope)
    
    elseif name[1] == 'statement' then
        this:compileNode(node[1])
        this:emit(";\n")
    
    elseif name[1] == 'FuncCall' then
        local funcname = node[1].value
        
        if VergeC.runtime.libfunc[funcname] then
            VergeC.runtime.libfunc[funcname](this, unpack(node[2]))
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
        local opstep = false
        local assign = false
        local i = 1
        local childcount = #node
                
        -- We're not doing chains of binops yet
        if childcount == 3 then
            local lhs = node[i]
            local op = node[2].token_type
            local rhs = node[i+2]
            
            -- special case ops; in these cases we can't just let Lua do its default thing because
            -- VergeC has a different idea of how things work
            if VergeC.runtime.op[op] then
                this:emit('VergeC.runtime.op.' .. op .. '(') this:compileNode(lhs) this:emit(', ') this:compileNode(rhs) this:emit(')')
            elseif op == 'OP_ASSIGN' then
                this:compileNode(lhs) this:emit(' = (') this:compileNode(rhs) this:emit(')')
            else
                this:emit('(') this:compileNode(lhs) this:emit(') ') this:compileNode(node[2]) this:emit(' (') this:compileNode(rhs) this:emit(') ')
            end
        else
            --for i,v in ipairs(node) do
            --    if not opstep and node[i+1] and node[i+1].token_type == 'OP_ASSIGN' then assign = true end
            --    
            --    if not assign and not opstep then this:emit("(") end
            --    this:compileNode(v)
            --    if not assign and not opstep then this:emit(") ") else this:emit(" ") end
            --    assign = false
            --    opstep = not opstep
            --end
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
        this:compileNode(node[1])
        if #node > 1 then
            this:emit('[1 + ')
            this:compileNode(node[2])
            this:emit(']')
        end
    
    -- then deal with generic types
    elseif node.type == 'EXPR' then
        this:compileNode(node[1])
    
    elseif node.type == 'TOKEN' then
        if node.token_type == 'NUMBER'
            or node.token_type == 'OP_ADD' or node.token_type == 'OP_SUB' or node.token_type == 'OP_MLT' or node.token_type == 'OP_DIV'
            or node.token_type == 'OP_ASSIGN' or node.token_type == 'OP_EQ'
            or node.token_type == 'OP_GT' or node.token_type == 'OP_LT' or node.token_type == 'OP_GTE' or node.token_type == 'OP_LTE'
        then
            this:emit(node.value)
        elseif node.token_type == 'OP_NE' then
            this:emit("~=")
        elseif node.token_type == 'STRING' then
            this:emit('"' .. node.value .. '"')
        elseif node.token_type == 'KEY_BREAK' then
            this:emit('do break end')
        elseif node.token_type == 'IDENT' then
            local found, scopelevel
            found, scopelevel = VergeC.findVarInScope(this, node.value)
            if found then
                if level == 1 then this:emit("VergeC.bin.") end
                this:emit(node.value)
            else
                VergeC.error("COMPILE ERROR\n  Unknown variable '" .. node.value .. "'.", node.index)
            end
        end
    
    elseif node.type == 'SEQ' then
        for i,v in ipairs(node) do
            this:compileNode(v)
        end
    end
end
