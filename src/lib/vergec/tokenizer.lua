-- Lexing functions
-- Define possible tokens
VergeC.tokens = {
    {'OP_EQ','=='},{'OP_NE','!='},{'OP_ASSIGN','='},
    {'OP_BSL','<<'},{'OP_BSR','>>'},
    {'OP_BAND','%&'},{'OP_BOR','%|'},{'OP_BXOR','%^'},
    {'OP_LTE','<='},{'OP_GTE','>='},{'OP_LTE','<='},{'OP_GTE','>='},{'OP_LT','<'},{'OP_GT','>'},
    {'OP_AND','%&%&'},{'OP_OR','%|%|'},
    {'OP_BNOT','~'},{'OP_NOT','!'},{'OP_INCREMENT','%+%+'},{'OP_DECREMENT','%-%-'},
    {'OP_ADD','%+'}, {'OP_SUB','%-'},{'OP_MLT','%*'},{'OP_DIV','%/'},{'OP_MOD','%%'},
    {'KEY_IF','if'},{'KEY_UNLESS','unless'},{'KEY_ELSE','else'},{'KEY_WHILE','while'},{'KEY_FOR','for'},{'KEY_RETURN','return'},{'KEY_STRUCT','struct'},
    {'KEY_SWITCH','switch'},{'KEY_CASE','case'},{'KEY_DEFAULT','default'},
    {'KEY_BREAK','break'},{'KEY_CONTINUE','continue'},
    {'TY_VOID','void'},{'TY_INT','int'},{'TY_STRING','string'},{'TY_FLOAT','float'},
    {'BRACE_OPEN','{'},{'BRACE_CLOSE','}'},{'BRACKET_OPEN','%['},{'BRACKET_CLOSE','%]'},{'PAREN_OPEN','%('},{'PAREN_CLOSE','%)'},
    {'COMMA',','},{'DOT','%.'},{'COLON',':'},
    {'NUMBER','%d+'},{'CHAR',"'"},{'STRING','"'}, -- string and character have special handling; see VergeC.peek
    {'IDENT','[_%w][_%w%d]*'},{'SEMICOLON',';'}
    
    -- NUMBER -> %d+(%.%d+)?
}

-- Look at the next token (don't consume).
function VergeC.peek(this)
    local code = this.code
    local index = this.index
    local codelen = string.len(code)

    for x,p in ipairs(VergeC.tokens) do
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
            elseif p[1] == 'CHAR' then
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
