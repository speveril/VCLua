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

function named(nm, node) node.name = nm; return node end        -- give the node a name
function ignore(node) node.ignore = true; return node end       -- parse, but don't include in the AST
function collapse(node) node.collapse = true; return node end   -- allow this node to "collapse" into its children

-- not implemented yet...
function and_predicate(...) return { type='AND', ... } end      -- &e
function not_predicate(...) return { type='NOT', ... } end      -- !e

-- some special shorthand expressions
local any_type = choice(token('TY_VOID'), token('TY_INT'), token('TY_STRING'), token('TY_FLOAT'))

VergeC.parsing_expressions = {
    GlobalList = one_or_more(collapse(parsex('GlobalDecl'))),
    GlobalDecl = choice(collapse(named('globalfunc',parsex('FuncDecl'))), seq(collapse(named('globalvar',parsex('Decl'))),ignore(token('SEMICOLON')))),
    
    FuncDecl = named('func',seq(any_type, named('name',token('IDENT')), named('args',collapse(parsex('ArgDefn'))), named('body',collapse(parsex('Block'))))),
    ArgDefn = collapse(seq(ignore(token('PAREN_OPEN')), choice(seq(collapse(parsex('Decl')), collapse(zero_or_more(collapse(seq(ignore(token('COMMA')),collapse(parsex('Decl'))))))),empty()), ignore(token('PAREN_CLOSE')))),
    
    Block = seq(ignore(token('BRACE_OPEN')), named('block',collapse(parsex('StatementList'))), ignore(token('BRACE_CLOSE'))),
    StatementList = collapse(zero_or_more(collapse(parsex('Statement')))),
   
    Statement = named('statement',choice(parsex('IfStatement'), parsex('WhileStatement'), parsex('ForStatement'), seq(choice(parsex('FuncCall'), parsex('Decl'), collapse(parsex('Expr')), collapse(parsex('ReturnStatement'))), ignore(token('SEMICOLON'))))),
    
    IfStatement = seq(ignore(token('KEY_IF')), ignore(token('PAREN_OPEN')), named('clause',parsex('Expr')), ignore(token('PAREN_CLOSE')), named('inner',choice(parsex('Block'), parsex('Statement')))),
    WhileStatement = seq(token('KEY_WHILE'), ignore(token('PAREN_OPEN')), parsex('Expr'), ignore(token('PAREN_CLOSE')), choice(parsex('Block'), parsex('Statement'))),
    ForStatement = seq(token('KEY_FOR'), ignore(token('PAREN_OPEN')), optional(parsex('Expr')), ignore(token('SEMICOLON')), optional(parsex('Expr')), ignore(token('SEMICOLON')), optional(parsex('Expr')), ignore(token('PAREN_CLOSE')), choice(parsex('Block'), parsex('Statement'))),
    ReturnStatement = collapse(seq(ignore(token('KEY_RETURN')), named('return',parsex('Expr')))),

    FuncCall = seq(token('IDENT'), collapse(parsex('ArgList'))),
    ArgList = seq(ignore(token('PAREN_OPEN')), optional(collapse(seq(parsex('Expr'), collapse(zero_or_more(collapse(seq(ignore(token('COMMA')),parsex('Expr')))))))), ignore(token('PAREN_CLOSE'))),

    Decl = named('decl',seq(named('type',any_type), named('name',token('IDENT')), named('initial',optional(seq(ignore(token('OP_ASSIGN')), collapse(parsex('Expr'))))))),

    -- expression order of operations chain
    --  ordered from binds most-tightly to least-tightly
    Value = named('value',choice(parsex('FuncCall'), token('IDENT'), token('NUMBER'), token('STRING'), seq(token('PAREN_OPEN'), parsex('Expr'), token('PAREN_CLOSE')))),
    PostfixOp = choice(named('postop', collapse(seq(parsex('Value'), choice(token('OP_INCREMENT'), token('OP_DECREMENT'))))), collapse(parsex('Value'))),
    PrefixOp = choice(named('preop', collapse(seq(choice(token('OP_NOT'), token('OP_INCREMENT'), token('OP_DECREMENT'), token('OP_SUB')), parsex('PostfixOp')))), collapse(parsex('PostfixOp'))),
    Product = choice(collapse(named('binop', seq(parsex('PrefixOp'), collapse(one_or_more(collapse(seq(choice(token('OP_MLT'), token('OP_DIV')), parsex('PrefixOp')))))))), collapse(parsex('PrefixOp'))),
    Sum = choice(collapse(named('binop', seq(parsex('Product'), collapse(one_or_more(collapse(seq(choice(token('OP_ADD'), token('OP_SUB')), parsex('Product')))))))), collapse(parsex('Product'))),
    Comparison = choice(collapse(named('binop', seq(parsex('Sum'), collapse(one_or_more(collapse(seq(choice(token('OP_EQ'), token('OP_NE'), token('OP_LTE'), token('OP_GTE'), token('OP_LT'), token('OP_GT')), parsex('Sum')))))))), collapse(parsex('Sum'))),
    BooleanOp = choice(collapse(named('binop', seq(parsex('Comparison'), collapse(one_or_more(collapse(seq(choice(token('OP_AND'), token('OP_OR')), parsex('Comparison')))))))), collapse(parsex('Comparison'))),
    Assignment = choice(collapse(named('binop',seq(parsex('BooleanOp'), collapse(one_or_more(collapse(seq(token('OP_ASSIGN'), parsex('BooleanOp')))))))), collapse(parsex('BooleanOp'))),
    Expr = parsex('Assignment'),
}

VergeC.default_parsing_expression = 'GlobalList'

-- set up the 'name' field for each parsing expression
for k,v in pairs(VergeC.parsing_expressions) do if not VergeC.parsing_expressions[k]['name'] then VergeC.parsing_expressions[k]['name'] = k end end

-- Build an AST
function VergeC.parse(this, what)
    local rootex = false

    if not what then what = VergeC.default_parsing_expression end
    
    if type(what) == 'string' then
        what = VergeC.parsing_expressions[what]
        rootex = true
    end

    local startindex = this.index
    local type = what.type
    
    local node = { name=what.name, collapse=what.collapse, type=what.type }
    local parsed = false
    
    --if what.name then print("  Parsing type: ", what.name, type) end
    
    if type == 'DEBUG_PRINT' then
        print(what.s)
    elseif type == 'EMPTY' then
        node.value = ''
        parsed = true
    elseif type == 'TOKEN' then
        local ty,val,idx = this:peek()
        if ty == what[1] then
            this:consume(idx)
            node.token_type = ty
            node.value = val
            parsed = true
        end
    elseif type == 'EXPR' then
        if VergeC.parsing_expressions[what[1]] then
            child,parsed = this:parse(what[1])
            if what.collapse then
                if child then
                    if child.name and what.name then
                        child.name = child.name .. "/" .. what.name
                    elseif what.name then
                        child.name = what.name
                    end
                end
                node = child
            else
                table.insert(node, child)
            end            
        else
            print("ERROR: Badly formed parsing expression; expression '" .. what[1] .. "' does not exist!")
        end
    elseif type == 'SEQ' then
        local i,v
        local child,succ
        
        parsed = true
        
        for i,v in ipairs(what) do
            child,succ = this:parse(v)
            if succ then
                if child and child.collapse then
                    local i,v
                    for i,v in ipairs(child) do
                        table.insert(node,v)
                    end
                else
                    table.insert(node, child)
                end
            else
                parsed = false
                break
            end
        end
    elseif type == 'OR' then
        local i,v
        local child,succ
        for i,v in ipairs(what) do
            child,succ = this:parse(v)
            if succ then
                node = child
                if child.name and what.name then
                    child.name = child.name .. "/" .. what.name
                elseif what.name then
                    child.name = what.name
                end
                parsed = true
                break
            end
        end
    elseif type == 'ZOM' then
        local child,succ
        local at_least_one = false
        
        node.type = 'SEQ'
        parsed = true -- Zero-or-more can't ever fail
        
        while true do
            local v = what[1]
            child,succ = this:parse(v)
            if succ then
                if child.collapse then
                    for i,v in ipairs(child) do
                        table.insert(node, v)
                    end
                else
                    table.insert(node, child)
                end
                at_least_one = true
            else
                break
            end
        end
        
        if not at_least_one then node = nil end
    elseif type == 'OOM' then
        local child,succ
        local at_least_one = false
        
        node.type = 'SEQ'
        
        while true do
            local v = what[1]
            child,succ = this:parse(v)
            if succ then
                if child.collapse then
                    for i,v in ipairs(child) do
                        table.insert(node, v)
                    end
                else
                    table.insert(node, child)
                end
                at_least_one = true
            else
                break
            end
        end
        
        if at_least_one then parsed = true end
    elseif type == 'OPT' then
        local child,succ
        
        parsed = true -- optional can't ever fail
        child,succ = this:parse(what[1])
        
        if succ then
            node = child
            node.name = what.name
        else
            node = nil
        end
        
    end
    
    if what.ignore then node = nil end
    if node then node.index = this.index end
    
    if not parsed then
        this.index = startindex
        return nil, false
    else
        return node, true
    end
end
