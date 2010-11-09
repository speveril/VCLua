
-- Lexing functions
-- Define possible tokens
tokens = {
    {'OP_EQ','=='}, {'OP_NE','!='},{'OP_ASSIGN','='},
    {'OP_LTE','<='},{'OP_GTE','>='},{'OP_LTE', '<='},{'OP_GTE','>='},{'OP_LT', '<'},{'OP_GT','>'},
    {'OP_AND','%&%&'},{'OP_OR','%|%|'},{'OP_BSL','<<'},{'OP_BSR','>>'},
    {'OP_NOT','!'}, {'OP_INCREMENT', '%+%+'}, {'OP_DECREMENT', '%-%-'},
    {'OP_ADD','%+'}, {'OP_SUB','%-'}, {'OP_MLT','%*'}, {'OP_DIV','%/'}, 
    {'KEY_IF', 'if'},{'KEY_WHILE', 'while'},{'KEY_FOR', 'for'},{'KEY_RETURN', 'return'},
    {'TY_VOID','void'},{'TY_INT','int'},{'TY_STRING','string'},{'TY_FLOAT','float'},
    {'BRACE_OPEN','{'},{'BRACE_CLOSE','}'},{'BRACKET_OPEN','%['},{'BRACKET_CLOSE','%]'},{'PAREN_OPEN','%('},{'PAREN_CLOSE','%)'},
    {'COMMA',','}, {'DOT','%.'},
    {'NUMBER','%d+'},{'CHAR',"'"},{'STRING','"'}, -- string and character has special handling; see VergeC.lookNextToken
    {'IDENT', '%w+'},{'SEMICOLON',';'}
    
    -- NUMBER -> %d+(%.%d+)?
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
