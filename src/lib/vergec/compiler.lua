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

function VergeC.compile(this)
    print("COMPILE STEP")
    
    this.scope = { {} } -- scope[1] is global scope, which we always have
    
    this:compileNode(this.ast)
    
    print(this.compiledcode)
end

function VergeC.emit(this, str)
    this.compiledcode = this.compiledcode .. str
end

function VergeC.compileNode(this, node)
    dbg = 'Compiling node'
    if node.name then dbg = dbg .. " '"..node.name.."'" end
    if node.type then dbg = dbg .. " ("..node.type..")" end
    print(dbg)
    
    local name = {}
    if node.name then
        name = string.split(node.name, '/')
    end
    
    -- first deal with special names
    if name[1] == 'decl' then
        local scope = #this.scope
        
        print('var [' .. scope .. ']: ' .. node[1].type .. ' ' .. node[2].value)
        if this.scope[scope][node[2]] then
            v3.exit("VERGEC: Compile error\n   Global variable '" .. node.name .. "'")
        else
            this.scope[1][node[2]] = { type = node[1].token_type, ident = node[2].value }
            this:emit(node[2].value .. " = ")
            if node[3] then
                print("globalvar has init")
                this:compileNode(node[3])
            else
                print("globalvar does not have init")
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
            -- need to pay attention to type somehow
            this:emit("function " .. node[2].value .. "(")
            this:compileNode(node[3])
            this:emit(")\n")
            this:compileNode(node[4])
            this:emit("end")
        end
    
    
    
    -- then deal with generic types
    elseif node.type == 'TOKEN' then
        if node.token_type == 'NUMBER' or node.token_type == 'IDENT' then
            this:emit(node.value)
        end
    elseif node.type == 'SEQ' then
        for i,v in ipairs(node) do
            this:compileNode(v)
        end
    end
end