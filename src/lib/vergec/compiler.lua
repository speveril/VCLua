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

VergeC.libfuncs = {
    log = function(this, str) this:emit('v3.log(') this:compileNode(str) this:emit(')') end,
}

function VergeC.compile(this)
    print("COMPILE STEP")
    
    this.scope = { {} } -- scope[1] is global scope, which we always have
    
    this:compileNode(this.ast)
end

function VergeC.emit(this, str)
    this.compiledcode = this.compiledcode .. str
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
        
        -- TODO need to pay attention to type somehow
        if this.scope[scope][node[2]] then
            v3.exit("VERGEC: Compile error\n   Global variable '" .. node.name .. "'")
        else
            if name[2] ~= 'globalvar' then this:emit("local ") end
            this.scope[1][node[2]] = { type = node[1].token_type, ident = node[2].value }
            this:emit(node[2].value .. " = ")
            if node[3] then
                this:compileNode(node[3])
            else
                if node[1].token_type == 'TY_INT' or node[1].token_type == 'TY_FLOAT' then
                    this:emit('0')
                elseif node[1].token_type == 'TY_FLOAT' then
                    this:emit('""')
                end
            end
            
            if name[2] == 'globalvar' then this:emit("\n") end
        end
        
    elseif name[1] == 'func' then
        if name[2] == 'globalfunc' then
            table.insert(this.scope, {})
            local localscope = this.scope[#this.scope]
            
            -- build function head and signature
            local first = true
            this:emit("function VergeC.bin." .. node[2].value .. "(")
            for i,v in ipairs(node[3]) do
                if first then first = false else this:emit(",") end
                -- TODO need to pay attention to type somehow
                this:emit(v[2].value)
                table.insert(localscope, { type = v[1].token_type, ident = v[2].value, init = v[3] })
            end
            this:emit(")\n")
            
            -- do inits
            
            for i,v in ipairs(localscope) do
                this:emit('if ' .. v.ident .. ' == nil then ' .. v.ident .. ' = ')
                if v.init then
                    this:compileNode(v.init)
                else
                    if node[1].token_type == 'TY_INT' or node[1].token_type == 'TY_FLOAT' then
                        this:emit('0')
                    elseif node[1].token_type == 'TY_FLOAT' then
                        this:emit('""')
                    end
                end
                this:emit(" end\n")
            end
            
            if node[4] then this:compileNode(node[4]) end
            this:emit("end\n\n")
            
            table.remove(this.scope)
        end
        
    elseif name[1] == 'statement' then
        this:compileNode(node[1])
        this:emit("\n")
    
    elseif name[1] == 'FuncCall' then
        local funcname = node[1].value
        
        if VergeC.libfuncs[funcname] then
            VergeC.libfuncs[funcname](this, unpack(node[2]))
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
        this:emit('return ')
        this:compileNode(node[1])
    
    elseif name[1] == 'binop' then
        local opstep = false
        local assign = false
        for i,v in ipairs(node) do
            if not opstep and node[i+1] and node[i+1].token_type == 'OP_ASSIGN' then assign = true end
            
            if not assign and not opstep then this:emit("(") end
            this:compileNode(v)
            if not assign and not opstep then this:emit(") ") else this:emit(" ") end
            assign = false
            opstep = not opstep
        end
        
    
    -- then deal with generic types
    elseif node.type == 'EXPR' then
        this:compileNode(node[1])
    elseif node.type == 'TOKEN' then
        if node.token_type == 'NUMBER'
            or node.token_type == 'OP_ADD' or node.token_type == 'OP_SUB' or node.token_type == 'OP_MLT' or node.token_type == 'OP_DIV'
            or node.token_type == 'OP_ASSIGN' or node.token_type == 'OP_EQ'
        then
            this:emit(node.value)
        elseif node.token_type == 'STRING' then
            this:emit('"' .. node.value .. '"')
        elseif node.token_type == 'IDENT' then
            -- TODO check through scope to see if the identifier's been defined yet
            this:emit(node.value)
        end
    elseif node.type == 'SEQ' then
        for i,v in ipairs(node) do
            this:compileNode(v)
        end
    end
end