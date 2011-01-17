-- Lexing functions
-- Define possible tokens
VergeC.tokens = {
    OP_EQ='==',OP_NE='!=',OP_ASSIGN='=',
    OP_BSL='<<',OP_BSR='>>',
    OP_BAND='%&',OP_BOR='%|',OP_BXOR='%^',
    OP_LTE='<=',OP_GTE='>=',OP_LTE='<=',OP_GTE='>=',OP_LT='<',OP_GT='>',
    OP_AND='%&%&',OP_OR='%|%|',
    OP_BNOT='~',OP_NOT='!',OP_INCREMENT='%+%+',OP_DECREMENT='%-%-',
    OP_ADD='%+', OP_SUB='%-',OP_MLT='%*',OP_DIV='%/',OP_MOD='%%',
    OP_ADDASSIGN='%+%=', OP_SUBASSIGN='%-%=',OP_MLTASSIGN='%*%=',OP_DIVASSIGN='%/%=',OP_MODASSIGN='%%%=',
    KEY_IF='if',KEY_UNLESS='unless',KEY_ELSE='else',KEY_WHILE='while',KEY_FOR='for',KEY_RETURN='return',KEY_STRUCT='struct',
    KEY_SWITCH='switch',KEY_CASE='case',KEY_DEFAULT='default',
    KEY_BREAK='break',KEY_CONTINUE='continue',
    TY_VOID='void',TY_INT='int',TY_STRING='string',TY_FLOAT='float',
    BRACE_OPEN='{',BRACE_CLOSE='}',BRACKET_OPEN='%[',BRACKET_CLOSE='%]',PAREN_OPEN='%(',PAREN_CLOSE='%)',
    COMMA=',',DOT='%.',COLON=':',
    NUMBER='%d+',CHAR="'",STRING='"', -- string and character have special handling; see VergeC.peek
    IDENT='[_%w][_%w%d]*',SEMICOLON=';'
}

VergeC.reserved = {
    'if','unless','else','while','for','return','struct',
    'switch','case','default',
    'break','continue',
    'void','int','string','float'
}

VergeC.reserved_lookup = {}
for i,v in ipairs(VergeC.reserved) do VergeC.reserved_lookup[v] = i end

-- Look at the next token (don't consume).
function VergeC.peek(this, type)
    if type then
        return this:matchToken(type)
    else
        for k,v in pairs(VergeC.tokens) do
            local a,b,c = this:matchToken(k)
            if a then return a,b,c end
        end
    end
        
    return nil, nil, this.index
end

function VergeC.matchToken(this,key)
    local code = this.code
    local index = this.index
    local codelen = this.codelen
    local form = VergeC.tokens[key]

    local m = string.match(code, '^'..form, index)
    if m then
        if key == 'STRING' then
            m = ''
            index = index + 1
            c = string.sub(code, index, index)
            while c ~= '"' and index < string.len(code) do
                if c == '\\' then
                    index = index + 1
                    c = string.sub(code, index, index)
                    if c == 'n' then c = "\\n"
                    elseif c == 'b' then c = "\\b"
                    elseif c == 'r' then c = "\\r"
                    elseif c == 'f' then c = "\\f"
                    elseif c == 't' then c = "\\t"
                    elseif c == '"' then c = "\\\""
                    end
                end
                m = m .. c
                index = index + 1
                c = string.sub(code, index, index)
            end
            index = index + 1 -- skip over the final quote
        elseif key == 'CHAR' then
            if string.sub(code, index+2, index+2) == "'" then
                m = string.sub(code, index+1, index+1)
                index = index + 3
            elseif string.sub(code, index+1, index+1) == '\\' and string.sub(code, index+3, index+3) == "'" then
                c = string.sub(code, index+2, index+2)
                if c == 'n' then c = "\\n"
                elseif c == 'b' then c = "\\b"
                elseif c == 'r' then c = "\\r"
                elseif c == 'f' then c = "\\f"
                elseif c == 't' then c = "\\t"
                elseif c == '"' then c = "\\\""
                end
                m = c
            else
                -- if we hit here, the tokenizing has failed
                --print("Failed to match " .. key)
                return nil, nil, index
            end
        elseif key == 'IDENT' then
            if VergeC.reserved_lookup[m] then
                return nil, nil, index
            else
                index = index + string.len(m)
            end
        else
            index = index + string.len(m)
        end
        
        --print("Matched " .. key .. " (" .. m .. ")")
        return key, m, index
    end
    
    --print("Failed to match " .. key)
    return nil, nil, this.index
end

-- Consume the next token.
function VergeC.consume(this, index)
    this.index = index
    
    -- skip whitespace and comments
    repeat
        local m = string.match(this.code, "^%s+", this.index) or string.match(this.code, "^//.-\n", this.index) or string.match(this.code, "^/%*.-%*/", this.index)
        --print("Consuming whitespace <" .. tostring(m) .. ">")
        if m then this.index = this.index + string.len(m) end
    until not m
    
    if this.index > this.furthestindex then this.furthestindex = this.index end
end
