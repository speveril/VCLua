-- Our VergeC state
VergeC = {}

function VergeC.newModule()
    local m = {}
    
    m.index = 1
    m.furthestindex = 1
    m.code = ''
    m.ast = {}
    m.compiledcode = ''
    
    m.addLine = VergeC.addLine
    m.preprocess = VergeC.preprocess
    m.parse = VergeC.parse
    m.compile = VergeC.compile
    m.peek = VergeC.peek
    m.consume = VergeC.consume
    
    return m
end

function VergeC.addLine(this, ln)
    this.code = this.code .. ln .. "\n"
end

-- Load a file and bring it into our VergeC state
function VergeC.loadfile(filename)
    print("VERGEC: Loading file '"..filename.."'")

    module = VergeC.newModule()    
    for line in io.lines(filename) do
        module:addLine(line)
    end
    
    module:preprocess()
    print(module.code)
    
    local succ
    module.ast,succ = module:parse(parsing_expressions.GlobalList)
    
    if succ then    
        print("Parsing successful!")
    else
        local c = module.code
        local lineno = 1
        local lastnewln = 0
        local i
        
        for i = 1,module.furthestindex do
            if string.char(string.byte(c, i)) == "\n" then
                lastnewln = i
                lineno = lineno + 1
            end
        end
        
        local ln = string.sub(c, lastnewln + 1, string.find(c, "\n", lastnewln + 1, true) - 1)
        local col = module.furthestindex - lastnewln + 1
        
        ln = string.gsub(ln, "\t", "    ")
                
        print("** VERGEC PARSE FAILURE near line " .. lineno .. ", column " .. col .. ":")
        print(ln)
        print(string.rep(" ", col-1) .. "^")
        
        return
    end

    VergeC.simplifyAST(module.ast)
    VergeC.printAST(module.ast)
    
    module:compile()
    
    -- done
end

-- Does preprocessing on the code
function VergeC.preprocess(this)
    print("VERGEC:  Preprocessing...")
    
    -- TODO: Parse #includes and #defines
    
    -- Strip comments
    this.code = string.gsub(this.code, "//.-\n", "\n")
    
    for comm in string.gmatch(this.code, "/%*(.-)%*/") do
        local repl = string.gsub(comm, "[^\n]", "")
        this.code = string.gsub(this.code, "/%*(.-)%*/", repl, 1)
    end
end

-- AST functions
-- Define grammar rules
--[[

Parsing expressions are one of:
    E    - empty string ()
    TOK  - token ( t )
    SEQ  - sequence ( e1 e2 )
    OR   - or ( e1 / e2)
    ZOM  - zero-or-more ( e* )   
    OOM  - one-or-more ( e+ )
    OPT  - optional ( e? )
    AND  - and-predicate ( &e )
    NOT  - not-predicate ( !e )
  
]]

-- atomics
function empty() return { type='EMPTY', ''} end                 -- empty string
function token(id) return { type='TOKEN', id} end               -- token
function parsex(id) return { type='EXPR', id} end               -- another parsing expression

-- operators
function seq(...) return { type='SEQ', ... } end                -- e1 e2 e3 ...
function choice(...) return { type='OR', ... } end              -- e1 / e2 / e2 ...
function zero_or_more(...) return { type='ZOM', ... } end       -- e*
function one_or_more(...) return { type='OOM', ... } end        -- e+
function optional(...) return { type='OPT', ... } end           -- e?

function debug(str) return {type='DEBUG_PRINT', s=str} end

-- not implemented yet...
function and_predicate(...) return { type='AND', ... } end      -- &e
function not_predicate(...) return { type='NOT', ... } end      -- !e

-- some special shorthand expressions
local any_type = choice(token('TY_VOID'), token('TY_INT'), token('TY_STRING'), token('TY_FLOAT'))

parsing_expressions = {
    GlobalList = one_or_more(parsex('GlobalDecl')),
    GlobalDecl = choice(parsex('FuncDecl'), seq(parsex('Decl'),token('SEMICOLON'))),
    
    FuncDecl = seq(any_type, token('IDENT'), parsex('ArgDefn'), parsex('Block')),
    ArgDefn = seq(token('PAREN_OPEN'), optional(seq(parsex('Decl'), zero_or_more(seq(token('COMMA'),parsex('Decl'))))), token('PAREN_CLOSE')),
    
    Block = seq(token('BRACE_OPEN'), parsex('StatementList'), token('BRACE_CLOSE')),
    StatementList = zero_or_more(parsex('Statement')),
   
    Statement = choice(parsex('IfStatement'), parsex('WhileStatement'), parsex('ForStatement'), seq(choice(parsex('FuncCall'), parsex('Decl'), parsex('Expr')), token('SEMICOLON'))),
    
    IfStatement = seq(token('KEY_IF'), token('PAREN_OPEN'), parsex('Expr'), token('PAREN_CLOSE'), choice(parsex('Block'), parsex('Statement'))),
    WhileStatement = seq(token('KEY_WHILE'), token('PAREN_OPEN'), parsex('Expr'), token('PAREN_CLOSE'), choice(parsex('Block'), parsex('Statement'))),
    ForStatement = seq(token('KEY_FOR'), token('PAREN_OPEN'), optional(parsex('Expr')), token('SEMICOLON'), optional(parsex('Expr')), token('SEMICOLON'), optional(parsex('Expr')), token('PAREN_CLOSE'), choice(parsex('Block'), parsex('Statement'))),

    FuncCall = seq(token('IDENT'), parsex('ArgList')),
    ArgList = seq(token('PAREN_OPEN'), optional(seq(parsex('Expr'), zero_or_more(seq(token('COMMA'),parsex('Expr'))))), token('PAREN_CLOSE')),

    Decl = seq(any_type, token('IDENT'), optional(seq(token('OP_ASSIGN'), parsex('Expr')))),

    -- expression order of operations chain
    --  ordered from binds most-tightly to least-tightly
    Value = choice(parsex('FuncCall'), token('IDENT'), token('NUMBER'), token('STRING'), seq(token('PAREN_OPEN'), parsex('Expr'), token('PAREN_CLOSE'))),
    UnaryOp = seq(optional(choice(token('OP_NOT'), token('OP_INCREMENT'), token('OP_DECREMENT'))), parsex('Value'), optional(choice(token('OP_INCREMENT'), token('OP_DECREMENT')))),
    Product = seq(parsex('UnaryOp'), zero_or_more(seq(choice(token('OP_MLT'), token('OP_DIV')), parsex('UnaryOp')))),
    Sum = seq(parsex('Product'), zero_or_more(seq(choice(token('OP_ADD'), token('OP_SUB')), parsex('Product')))),
    Comparison = seq(parsex('Sum'), zero_or_more(seq(choice(token('OP_EQ'), token('OP_NE'), token('OP_LT'), token('OP_GTE'), token('OP_LT'), token('OP_GT')), parsex('Sum')))),
    Assignment = seq(parsex('Comparison'), zero_or_more(seq(token('OP_ASSIGN'), parsex('Comparison')))),
    Expr = seq(parsex('Assignment')),
}

-- set up the 'name' field for each parsing expression
for k,v in pairs(parsing_expressions) do parsing_expressions[k]['name'] = k end

-- Build an AST
function VergeC.parse(this, what)
    local startindex = this.index
    local type = what.type
    
    --if what.name then print("  Parsing type: ", what.name, type) end
    
    if type == 'EMPTY' then
        return { name=what.name, type='EMPTY', value='' }, true
    elseif type == 'DEBUG_PRINT' then
        print(what.s)
    elseif type == 'TOKEN' then
        local ty,val = this:peek()
        if ty == what[1] then
            this:consume()
            return { name=what.name, type='TOKEN', value=val, token_type=ty }, true
        end
    elseif type == 'EXPR' then
        return this:parse(parsing_expressions[what[1]], what[1])
    elseif type == 'SEQ' then
        local i,v
        local node = { name=what.name, type='SEQ' }
        local child,succ
        for i,v in ipairs(what) do
            child,succ = this:parse(v)
            if succ then
                table.insert(node, child)
            else
                this.index = startindex
                return nil, false
            end
        end
        
        return node,true
    elseif type == 'OR' then
        local i,v
        local child,succ
        for i,v in ipairs(what) do
            child,succ = this:parse(v)
            if succ then
                return { name=what.name, type='OR', child }, true
            end
        end
    elseif type == 'ZOM' then
        local node = { name=what.name, type='ZOM' }
        local child,succ
        local done = false
        
        while not done do
            local v = what[1]
            child,succ = this:parse(v)
            if succ then
                table.insert(node, child)
            else
                done = true
                break
            end
        end
        
        return node,true
    elseif type == 'OOM' then
        local node = { name=what.name, type='OOM' }
        local child,succ
        local done = false
        local at_least_one = false
        
        while not done do
            local v = what[1]
            child,succ = this:parse(v)
            if succ then
                table.insert(node, child)
                at_least_one = true
            else
                done = true
                break
            end
        end
        
        if at_least_one then
            return node,true
        else
            return nil, false
        end
    elseif type == 'OPT' then
        local node = { name=what.name, type='OPT' }
        local v = what[1]
        child,succ = this:parse(v)
        if succ then
            table.insert(node, child)
        end
        
        return node, true
    end
    
    -- if we've hit here we've failed, so rollback and return nothing
    this.index = startindex
    return nil, false
end

-- Print out an AST
function VergeC.printAST(ast, indent)
    if not ast then return end
    if not indent then indent = 0 end
    
    local sp = string.rep(' ', indent)
    local i,v
    
    local nodedesc = "Node: "
    if ast.name then nodedesc = nodedesc .. ast.name .. " " end
    if ast.type == 'TOKEN' then
        nodedesc = nodedesc .. "'" .. ast.value .. "' (" .. ast.token_type .. ")"
    else
        nodedesc = nodedesc .. "("..ast.type
        if ast.value then nodedesc = nodedesc .. ", " .. ast.value end
        nodedesc = nodedesc .. ")"
    end
    print(sp..nodedesc)

    for i,v in ipairs(ast) do
        VergeC.printAST(v,indent+2)
    end
end

function VergeC.simplifyAST(ast)
    local i,v
    
    if ast.type == 'OOM' then
        if table.maxn(ast) == 0 then return nil end
        
        for i, v in ipairs(ast) do
            ast[i] = simplifyAST(v)
        end
    end
    
    return ast
end

-- Lexing functions
-- Define possible tokens
tokens = {
    {'OP_EQ','=='}, {'OP_NE','!='},{'OP_ASSIGN','='},
    {'OP_LTE','<='},{'OP_GTE','>='},{'OP_LTE', '<='},{'OP_GTE','>='},{'OP_LT', '<'},{'OP_GT','>'},
    {'OP_NOT','!'}, {'OP_INCREMENT', '%+%+'}, {'OP_DECREMENT', '%-%-'},
    {'OP_ADD','%+'}, {'OP_SUB','%-'}, {'OP_MLT','%*'}, {'OP_DIV','%/'}, 
    {'KEY_IF', 'if'},{'KEY_WHILE', 'while'},{'KEY_FOR', 'for'},
    {'TY_VOID','void'},{'TY_INT','int'},{'TY_STRING','string'},{'TY_FLOAT','float'},
    {'BRACE_OPEN','{'},{'BRACE_CLOSE','}'},{'BRACKET_OPEN','%['},{'BRACKET_CLOSE','%]'},{'PAREN_OPEN','%('},{'PAREN_CLOSE','%)'},
    {'COMMA',','}, {'DOT','%.'},
    {'NUMBER','%d+'},{'CHAR',"'"},{'STRING','"'}, -- string and character has special handling; see VergeC.lookNextToken
    {'IDENT', '%w+'},{'SEMICOLON',';'}
}

-- Look at the next token (don't consume).
function VergeC.peek(this)
    code = this.code
    index = this.index

    -- first, skip whitespace
    local m = string.match(code, "^%s*", index)
    if m then index = index + string.len(m) end

    for x,p in ipairs(tokens) do
        local m = string.match(code, '^'..p[2], index)
        if m then
            if p[1] == 'STRING' then
                m = ''
                index = index + 1
                c = string.sub(code, index, index)
                while c ~= '"' and index < string.len(code) do
                    if c == '\\' then
                        index = index + 1
                        c = string.sub(code, index, index)
                        if c == 'n' then c = "\n"
                        elseif c == 'b' then c = "\b"
                        elseif c == 'r' then c = "\r"
                        elseif c == 'f' then c = "\f"
                        elseif c == 't' then c = "\t"
                        end
                    end
                    m = m .. c
                    index = index + 1
                    c = string.sub(code, index, index)
                end
                index = index + 1 -- skip over the final quote
            elseif p[1] == 'CHAR' then
                if string.sub(code, index+2, index+2) == "'" then
                    m = string.sub(code, index+1, index+1)
                    index = index + 3
                else
                    -- if we hit here, the tokenizing has failed
                    return nil, nil, index
                end                
            else
                index = index + string.len(m)
            end
            
            return p[1], m, index
        end
    end

    return nil, nil, index
end

-- Consume the next token.
function VergeC.consume(this)
    index = this.index
    
    -- first, consume whitespace
    local m = string.match(code, "^%s*", index)
    if m then index = index + string.len(m) end

    -- get the next token
    local t
    local v
    t, v, index = this:peek()
    
    -- consume it
    this.index = index
    if this.index > this.furthestindex then this.furthestindex = this.index end
end

function VergeC.compile(this)
    
end
